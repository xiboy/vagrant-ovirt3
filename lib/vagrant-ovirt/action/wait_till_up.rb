require 'log4r'
require 'vagrant-ovirt/util/timer'
require 'vagrant/util/retryable'

module VagrantPlugins
  module OVirtProvider
    module Action

      # Wait till VM is started, till it obtains an IP address and is
      # accessible via ssh.
      class WaitTillUp
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt::action::wait_till_up")
          @app = app
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get config.
          config = env[:machine].provider_config

          # Wait for VM to obtain an ip address.
          env[:ip_address] = nil
          env[:metrics]["instance_ip_time"] = Util::Timer.time do
            env[:ui].info(I18n.t("vagrant_ovirt.waiting_for_ip"))
            #retryable(:on => Fog::Errors::TimeoutError, :tries => 300) do
            for i in 1..300
              # If we're interrupted don't worry about waiting
              next if env[:interrupted]

              # Get VM.
              server = env[:ovirt_compute].servers.get(env[:machine].id.to_s)
              if server == nil
                raise NoVMError, :vm_name => ''
              end

              env[:ip_address] = server.ips.first
              @logger.debug("Got output #{env[:ip_address]}")
              break if env[:ip_address] =~ /[0-9\.]+/
              sleep 2
            end
            #end
          end
          terminate(env) if env[:interrupted]
          @logger.info("Got IP address #{env[:ip_address]}")
          @logger.info("Time for getting IP: #{env[:metrics]["instance_ip_time"]}")
          
          # Machine has ip address assigned, now wait till we are able to
          # connect via ssh.
          env[:metrics]["instance_ssh_time"] = Util::Timer.time do
            env[:ui].info(I18n.t("vagrant_ovirt.waiting_for_ssh"))
            retryable(:on => Fog::Errors::TimeoutError, :tries => 60) do
              # If we're interrupted don't worry about waiting
              next if env[:interrupted]

              # Wait till we are able to connect via ssh.
              next if env[:machine].communicate.ready?
              sleep 2
            end
          end
          terminate(env) if env[:interrupted]
          @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

          # Booted and ready for use.
          env[:ui].info(I18n.t("vagrant_ovirt.ready"))
          
          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)        
        end
      end
    end
  end
end

