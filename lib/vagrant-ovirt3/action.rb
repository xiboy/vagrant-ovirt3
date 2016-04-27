require 'vagrant/action/builder'

module VagrantPlugins
  module OVirtProvider
    module Action
      # Include the built-in modules so we can use them as top-level things.
      include Vagrant::Action::Builtin

      # This action is called to bring the box up from nothing.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use Call, ReadState do |env, b2|
            if env[:machine_state_id] == :up
              b2.use SyncFolders
              b2.use MessageAlreadyUp
              next
            end

            if env[:machine_state_id] == :saving_state
              b2.use MessageSavingState
              next
            end

            if env[:machine_state_id] == :not_created
              b2.use SetNameOfDomain
              b2.use CreateVM
              b2.use ResizeDisk

              b2.use Provision
              b2.use CreateNetworkInterfaces

              b2.use SetHostname
            end

            b2.use StartVM
            b2.use WaitTillUp
            b2.use SyncFolders
          end
        end
      end

      def self.action_start
        with_ovirt do |env, b|
          if env[:machine_state_id] == :down
            b.use StartVM
            b.use WaitTillUp
            b.use SyncFolders
          end
        end
      end

      def self.action_halt
        with_ovirt do |env, b|
          if env[:machine_state_id] != :up
            b.use MessageNotUp
            next
          end
          b.use HaltVM
        end
      end

      def self.action_suspend
        with_ovirt do |env, b|
          if env[:machine_state_id] != :up
            b.use MessageNotUp
            next
          end
          b.use SuspendVM
        end
      end

      def self.action_resume
        with_ovirt do |env, b|
          if env[:machine_state_id] == :saving_state
            b.use MessageSavingState
            next
          end
          if env[:machine_state_id] != :suspended
            b.use MessageNotSuspended
            next
          end
          b.use StartVM
          b.use WaitTillUp
          b.use SyncFolders
        end
      end

      # This is the action that is primarily responsible for completely
      # freeing the resources of the underlying virtual machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectOVirt
            b3.use ProvisionerCleanup, :before if defined?(ProvisionerCleanup)
            b2.use DestroyVM
          end
        end
      end

      # This action is called to read the state of the machine. The resulting
      # state is expected to be put into the `:machine_state_id` key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use ReadState
        end
      end

      # This action is called to read the SSH info of the machine. The
      # resulting state is expected to be put into the `:machine_ssh_info`
      # key.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use ReadSSHInfo
        end
      end

      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use Call, ReadState do |env, b2|
            if env[:machine_state_id] == :not_created
              b2.use MessageNotCreated
              next
            end
            if env[:machine_state_id] != :up
              b2.use MessageNotUp
              next
            end
            b2.use SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use Call, ReadState do |env, b2|
            if env[:machine_state_id] == :not_created
              b2.use MessageNotCreated
              next
            end
            if env[:machine_state_id] != :up
              b2.use MessageNotUp
              next
            end
            b2.use SSHRun
          end
        end
      end

      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use Provision
            b2.use SyncFolders
          end
        end
      end

      # This is the action implements the reload command
      # It uses the halt and start actions
      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use Call, IsRunning do |env2, b3|
              # if vm is running keep going
              if env2[:result]
                b3.use ConfigValidate
                b3.use action_halt
                b3.use action_start
              end
            end
          end
        end
      end

      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :ConnectOVirt, action_root.join("connect_ovirt")
      autoload :IsCreated, action_root.join("is_created")
      autoload :IsRunning, action_root.join("is_running")
      autoload :SetNameOfDomain, action_root.join("set_name_of_domain")
      autoload :CreateVM, action_root.join("create_vm")
      autoload :CreateNetworkInterfaces, action_root.join("create_network_interfaces")
      autoload :ResizeDisk, action_root.join("resize_disk")
      autoload :StartVM, action_root.join("start_vm")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :HaltVM, action_root.join("halt_vm")
      autoload :SuspendVM, action_root.join("suspend_vm")
      autoload :DestroyVM, action_root.join("destroy_vm")
      autoload :ReadState, action_root.join("read_state")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :WaitTillUp, action_root.join("wait_till_up")
      autoload :SyncFolders, action_root.join("sync_folders")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageAlreadyUp, action_root.join("message_already_up")
      autoload :MessageNotUp, action_root.join("message_not_up")
      autoload :MessageSavingState, action_root.join("message_saving_state")
      autoload :MessageNotSuspended, action_root.join("message_not_suspended")

      autoload :ProvisionerCleanup, 'vagrant/action/builtin/provisioner_cleanup'

      private
      def self.with_ovirt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectOVirt
          b.use Call, ReadState do |env, b2|
            if !env[:machine_state_id] == :not_created
              b2.use MessageNotCreated
              next
            end
            yield env, b2
          end
        end
      end
    end
  end
end

