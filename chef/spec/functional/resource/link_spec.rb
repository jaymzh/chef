#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Chef::Resource::Link do

  let(:file_base) { "file_spec" }

  let(:to) do
    File.join(Dir.tmpdir, make_tmpname("to_spec", nil))
  end
  let(:target_file) do
    File.join(Dir.tmpdir, make_tmpname("from_spec", nil))
  end

  after(:each) do
    FileUtils.rm_r(to) if File.exists?(to)
    FileUtils.rm_r(target_file) if File.exists?(target_file)
    FileUtils.rm_r(CHEF_SPEC_BACKUP_PATH) if File.exists?(CHEF_SPEC_BACKUP_PATH)
  end

  def create_resource
    resource = Chef::Resource::Link.new(target_file)
    resource.to(to)
    resource
  end

  let!(:resource) do
    create_resource
  end

  shared_examples_for 'delete errors out' do
    it 'delete errors out' do
      lambda { resource.run_action(:delete) }.should raise_error(Chef::Exceptions::Link)
      (File.exist?(target_file) || File.symlink?(target_file)).should be_true
    end
  end

  shared_examples_for 'a successful delete' do
    before(:each) do
      resource.run_action(:delete)
    end
    it 'delete succeeds' do
      File.exist?(target_file).should be_false
      File.symlink?(target_file).should be_false
    end
  end

  shared_examples_for "a successful symbolic link" do
    before(:each) do
      resource.run_action(:create)
    end
    it "links to the target file" do
      File.symlink?(target_file).should be_true
      File.readlink(target_file).should == to
    end
    it_behaves_like 'a securable resource' do
      let(:path) { target_file }
    end
  end

  shared_examples_for 'a successful hard link' do
    before(:each) do
      resource.run_action(:create)
    end
    it 'links to the target file' do
      File.exists?(target_file).should be_true
      File.symlink?(target_file).should be_false
      # Writing to one hardlinked file should cause both
      # to have the new value.
      IO.read(to).should == IO.read(target_file)
      File.open(to, "w") { |file| file.write('wowzers') }
      IO.read(target_file).should == 'wowzers'
    end
  end

  context "is symbolic" do

    context "when the link destination is a file" do
      before(:each) do
        File.open(to, "w") do |file|
          file.write('woohoo')
        end
      end
      context "and the link does not yet exist" do
        it_behaves_like 'a successful symbolic link'
        context "with a relative link destination", :pending => "understanding this behavior" do
          before(:each) do
            resource.to(File.basename(target_file))
          end
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
        end
      end
      context "and the link already exists and is a symbolic link" do
        context "pointing at the target" do
          before(:each) do
            File.symlink(to, target_file)
            File.symlink?(target_file).should be_true
            File.readlink(target_file).should == to
          end
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
          context "and the target's owner is different than desired" do
            before(:each) do
              resource.owner('nobody')
            end
            it 'sets the owner to the desired state' do
              resource.run_action(:create)
              File.lstat(target_file).uid.should == Etc.getpwnam('nobody').uid
            end
          end
          context "and the target's group is different than desired" do
            before(:each) do
              resource.group('nogroup')
            end
            it 'sets the group to the desired state' do
              resource.run_action(:create)
              File.lstat(target_file).gid.should == Etc.getgrnam('nogroup').gid
            end
          end
        end
        context 'pointing somewhere else' do
          before(:each) do
            @other_target = File.join(Dir.tmpdir, make_tmpname("other_spec", nil))
            File.open(@other_target, "w") { |file| file.write("eek") }
            File.symlink(@other_target, target_file)
            File.symlink?(target_file).should be_true
            File.readlink(target_file).should == @other_target
          end
          after(:each) do
            File.delete(@other_target)
          end
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
        end
        context "pointing nowhere" do
          before(:each) do
            nonexistent = File.join(Dir.tmpdir, make_tmpname("nonexistent_spec", nil))
            File.symlink(nonexistent, target_file)
            File.symlink?(target_file).should be_true
            File.readlink(target_file).should == nonexistent
          end
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
        end
      end
      context 'and the link already exists and is a hard link to the file' do
        before(:each) do
          File.link(to, target_file)
          File.exists?(target_file).should be_true
          File.symlink?(target_file).should be_false
        end
        it_behaves_like 'a successful symbolic link'
        it_behaves_like 'delete errors out'
      end
      context 'and the link already exists and is a file' do
        before(:each) do
          File.open(target_file, "w") { |file| file.write("eek") }
        end
        it_behaves_like 'a successful symbolic link'
        it_behaves_like 'delete errors out'
      end
      context 'and the link already exists and is a directory' do
        before(:each) do
          Dir.mkdir(target_file)
        end
        it 'errors out' do
          lambda { resource.run_action(:create) }.should raise_error(Errno::EISDIR)
        end
        it_behaves_like 'delete errors out'
      end
      context 'and the link already exists and is not writeable to this user', :pending do
      end
    end
    context 'when the link destination is a directory' do
      before(:each) do
        Dir.mkdir(to)
      end
      context 'and the link does not yet exist' do
        it_behaves_like 'a successful symbolic link'
        it_behaves_like 'a successful delete'
      end
    end
    context "when the link destination is a symbolic link" do
      context 'to a file that exists' do
        before(:each) do
          @other_target = File.join(Dir.tmpdir, make_tmpname("other_spec", nil))
          File.open(@other_target, "w") { |file| file.write("eek") }
          File.symlink(@other_target, to)
          File.symlink?(to).should be_true
          File.readlink(to).should == @other_target
        end
        after(:each) do
          File.delete(@other_target)
        end
        context 'and the link does not yet exist' do
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
        end
      end
      context 'to a file that does not exist' do
        before(:each) do
          @other_target = File.join(Dir.tmpdir, make_tmpname("other_spec", nil))
          File.symlink(@other_target, to)
          File.symlink?(to).should be_true
          File.readlink(to).should == @other_target
        end
        context 'and the link does not yet exist' do
          it_behaves_like 'a successful symbolic link'
          it_behaves_like 'a successful delete'
        end
      end
    end
    context "when the link destination is not readable to this user", :pending do
    end
    context "when the link destination does not exist" do
      it_behaves_like 'a successful symbolic link'
      it_behaves_like 'a successful delete'
    end
  end

  context "is a hard link" do
    before(:each) do
      resource.link_type(:hard)
    end

    context "when the link destination is a file" do
      before(:each) do
        File.open(to, "w") do |file|
          file.write('woohoo')
        end
      end
      context "and the link does not yet exist" do
        it_behaves_like 'a successful hard link'
        it_behaves_like 'a successful delete'
      end
      context "and the link already exists and is a symbolic link pointing at the same file" do
        before(:each) do
          File.symlink(to, target_file)
          File.symlink?(target_file).should be_true
          File.readlink(target_file).should == to
        end
        it_behaves_like 'a successful hard link'
        it_behaves_like 'delete errors out'
      end
      context "and the link already exists and is a file" do
        before(:each) do
          File.open(target_file, 'w') { |file| file.write('tomfoolery') }
        end
        it_behaves_like 'a successful hard link'
        it_behaves_like 'delete errors out'
      end
      context "and the link already exists and is a directory" do
        before(:each) do
          Dir.mkdir(target_file)
        end
        it 'errors out' do
          lambda { resource.run_action(:create) }.should raise_error(Errno::EISDIR)
        end
        it_behaves_like 'delete errors out'
      end
      context "and the link already exists and is not writeable to this user", :pending do
      end
      context "and specifies security attributes" do
        before(:each) do
          resource.owner('nobody')
          resource.group('nogroup')
        end
        it 'ignores them' do
          resource.run_action(:create)
          File.lstat(target_file).uid.should_not == Etc.getpwnam('nobody').uid
          File.lstat(target_file).gid.should_not == Etc.getgrnam('nogroup').gid
        end
      end
    end
    context "when the link destination is a directory" do
      before(:each) do
        Dir.mkdir(to)
      end
      context 'and the link does not yet exist' do
        it 'create errors out' do
          lambda { resource.run_action(:create) }.should raise_error(Errno::EPERM)
        end
        it_behaves_like 'a successful delete'
      end
    end
    context "when the link destination is a symbolic link" do
      context 'to a real file' do
        before(:each) do
          @other_target = File.join(Dir.tmpdir, make_tmpname("other_spec", nil))
          File.open(@other_target, "w") { |file| file.write("eek") }
          File.symlink(@other_target, to)
          File.symlink?(to).should be_true
          File.readlink(to).should == @other_target
        end
        after(:each) do
          File.delete(@other_target)
        end
        context 'and the link does not yet exist' do
          it 'links to the target file' do
            resource.run_action(:create)
            File.exists?(target_file).should be_true
            File.symlink?(target_file).should be_true
            File.readlink(target_file).should == @other_target
          end
          it_behaves_like 'a successful delete'
        end
      end
      context 'to a nonexistent file' do
        before(:each) do
          @other_target = File.join(Dir.tmpdir, make_tmpname("other_spec", nil))
          File.symlink(@other_target, to)
          File.symlink?(to).should be_true
          File.readlink(to).should == @other_target
        end
        context 'and the link does not yet exist' do
          it 'links to the target file' do
            resource.run_action(:create)
            File.exists?(target_file).should be_false
            File.symlink?(target_file).should be_true
            File.readlink(target_file).should == @other_target
          end
          it_behaves_like 'a successful delete'
        end
      end
    end
    context "when the link destination is not readable to this user", :pending do
    end
    context "when the link destination does not exist" do
      context 'and the link does not yet exist' do
        it 'create errors out' do
          lambda { resource.run_action(:create) }.should raise_error(Errno::ENOENT)
        end
        it_behaves_like 'a successful delete'
      end
    end
  end
end
