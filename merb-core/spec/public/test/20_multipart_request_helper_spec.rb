require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))
require "merb-core/two-oh"

startup_merb(:log_level => :fatal)

Dir[File.join(File.dirname(__FILE__), "controllers/**/*.rb")].each do |f|
  require f
end

describe Merb::Test::MultipartRequestHelper do

  describe "#dispatch_multipart_to" do

    before(:all) do 
      @controller_klass = Merb::Test::DispatchController
    end

    it "should dispatch to the given controller and action" do
      Merb::Test::ControllerAssertionMock.should_receive(:called).with(:index)

      dispatch_multipart_to(@controller_klass, :index)    
    end

    it "should dispatch to the given controller and action with params" do
      Merb::Test::ControllerAssertionMock.should_receive(:called).with(:show)

      controller = dispatch_multipart_to(@controller_klass, :show, :name => "Fred")
      controller.params[:name].should == "Fred"
    end

    it "should handle a file object when used as a param" do
      Merb::Test::ControllerAssertionMock.should_receive(:called).with(:show)
      file_name = File.join(File.dirname(__FILE__), "multipart_upload_text_file.txt")
      File.open( file_name ) do |file|
        controller = dispatch_multipart_to(@controller_klass, :show, :my_file => file)
        file_params = controller.params[:my_file]
        file_params[:content_type].should == "text/plain"
        file_params[:size].should == File.size(file_name)
        file_params[:tempfile].should be_a_kind_of(Tempfile)
        file_params[:filename].should == "multipart_upload_text_file.txt"
      end
    end
  end

  describe "#multipart_post" do
    before(:each) do
      Merb::Router.prepare do
        resources :spec_helper_controller
      end
    end

    it "should post to the create action with params" do
      pending "Implementation of #multipart_request in the test helper is not working."

      resp = multipart_post("/spec_helper_controller", :name => "Harry")
      JSON(resp.body.to_s)["name"].should == "Harry"
    end

    it "should upload a file to the action using multipart" do
      pending "Implementation of #multipart_request in the test helper is not working."

      file_name = File.join(File.dirname(__FILE__), "multipart_upload_text_file.txt")
      File.open( file_name ) do |file|
        resp = multipart_post("/spec_helper_controller", :my_file => file)
        file_params = JSON(resp.body.to_s)["my_file"]
        file_params["content_type"].should == "text/plain"
        file_params["size"].should == File.size(file_name)
        file_params["tempfile"].should =~ /#<File:.*>/
        file_params["filename"].should == "multipart_upload_text_file.txt"
      end
    end

  end

  describe "#multipart_put" do
    before(:each) do
      Merb::Router.prepare do
        resources :spec_helper_controller
      end
    end

    it "should put to the update action with multipart params" do
      pending "Implementation of #multipart_request in the test helper is not working."

      Merb::Test::ControllerAssertionMock.should_receive(:called).with(:update)
      resp = multipart_put("/spec_helper_controller/my_id", :name => "Harry")

      params = JSON(resp.body.to_s).to_mash
      params[:name].should == "Harry"
      params[:id].should   == "my_id"
    end

    it "should upload a file to the action using multipart" do
      pending "Implementation of #multipart_request in the test helper is not working."

      Merb::Test::ControllerAssertionMock.should_receive(:called).with(:update)
      file_name = File.join(File.dirname(__FILE__), "multipart_upload_text_file.txt")
      File.open( file_name ) do |file|
        resp = multipart_put("/spec_helper_controller/my_id", :my_file => file)
        params = JSON(resp.body.to_s).to_mash
        params[:id].should == "my_id"
        file_params = params[:my_file]
        file_params[:content_type].should == "text/plain"
        file_params[:size].should == File.size(file_name)
        file_params[:tempfile].should =~ /#<File:.*>/
        file_params[:filename].should == "multipart_upload_text_file.txt"
      end
    end
  end
end

module Merb::Test::MultipartRequestHelper
  describe Param, '#to_multipart' do
    it "should represent the key and value correctly" do
      param = Param.new('foo', 'bar')
      param.to_multipart.should == %(Content-Disposition: form-data; name="foo"\r\n\r\nbar\r\n)
    end
  end

  describe FileParam, '#to_multipart' do
    it "should represent the key, filename and content correctly" do
      param = FileParam.new('foo', '/bar.txt', 'baz')
      param.to_multipart.should == %(Content-Disposition: form-data; name="foo"; filename="/bar.txt"\r\nContent-Type: text/plain\r\n\r\nbaz\r\n)
    end
  end

  describe Post, '#push_params(params) param parsing' do
    before(:each) do
      @fake_return_param = mock('fake return_param')
    end

    it "should create Param from params when param doesn't respond to read" do
      params = { 'normal' => 'normal_param' }
      Param.should_receive(:new).with('normal', 'normal_param').and_return(@fake_return_param)
      Post.new.push_params(params)
    end
  
    it "should create FileParam from params when param does response to read" do
      file_param = mock('file param')
      file_param.should_receive(:read).and_return('file contents')
      file_param.should_receive(:path).and_return('file.txt')
      params = { 'file' => file_param }
      FileParam.should_receive(:new).with('file', 'file.txt', 'file contents').and_return(@fake_return_param)
      Post.new.push_params(params)
    end
  end
  
  describe Post, '#to_multipart' do
    it "should create a multipart request from the params" do
      file_param = mock('file param')
      file_param.should_receive(:read).and_return('file contents')
      file_param.should_receive(:path).and_return('file.txt')
      params = { 'file' => file_param, 'normal' => 'normal_param' }
      multipart = Post.new(params)
      query, content_type = multipart.to_multipart
      content_type.should == "multipart/form-data, boundary=----------0xKhTmLbOuNdArY"
      query.should == "------------0xKhTmLbOuNdArY\r\nContent-Disposition: form-data; name=\"file\"; filename=\"file.txt\"\r\nContent-Type: text/plain\r\n\r\nfile contents\r\n------------0xKhTmLbOuNdArY\r\nContent-Disposition: form-data; name=\"normal\"\r\n\r\nnormal_param\r\n------------0xKhTmLbOuNdArY--"
    end
  end
end
