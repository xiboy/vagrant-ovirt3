require 'log4r'

module VagrantPlugins
  module OVirtProvider
    module Action

      # Just start the VM.
      class StartVM

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt::action::start_vm")
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          connect_timeout = config.connect_timeout
          env[:ui].info(I18n.t("vagrant_ovirt3.starting_vm"))

          for i in 0..connect_timeout
            ready = true

            machine = env[:ovirt_compute].servers.get(env[:machine].id.to_s)

            if env[:machine].state.id == :image_locked
              ready = false
            end

            if machine == nil
              raise Errors::NoVMError,
                :vm_name => env[:machine].id.to_s
            end

            break if ready
            sleep 2
          end

          if not ready
            raise Errors::WaitForReadyVmTimeout
          end

          # Start VM.
          begin
            machine.start
          rescue OVIRT::OvirtException => e
            raise Errors::StartVMError,
              :error_message => e.message
          end

          @app.call(env)
        end
      end
    end
  end
end
