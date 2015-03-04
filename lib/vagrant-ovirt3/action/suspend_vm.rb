require 'log4r'

module VagrantPlugins
  module OVirtProvider
    module Action
      class SuspendVM
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt3::action::suspend_vm")
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant_ovirt3.suspend_vm"))

          machine = env[:ovirt_compute].servers.get(env[:machine].id.to_s)
          machine.suspend

          @app.call(env)
        end
      end
    end
  end
end

