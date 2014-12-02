require 'log4r'

module VagrantPlugins
  module OVirtProvider
    module Action
      class DestroyVM
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt3::action::destroy_vm")
          @app = app
        end

        def call(env)
          # Destroy the server, remove the tracking ID
          env[:ui].info(I18n.t("vagrant_ovirt3.destroy_vm"))

          machine = env[:ovirt_compute].servers.get(env[:machine].id.to_s)
          machine.destroy
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
