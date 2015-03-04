require 'log4r'

module VagrantPlugins
  module OVirtProvider
    module Action
      class HaltVM
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt3::action::halt_vm")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_ovirt3.halt_vm"))

          machine = env[:ovirt_compute].servers.get(env[:machine].id.to_s)
          machine.stop

          @app.call(env)
        end
      end
    end
  end
end
