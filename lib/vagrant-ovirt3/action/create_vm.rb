require 'log4r'
require 'vagrant/util/retryable'

module VagrantPlugins
  module OVirtProvider
    module Action
      class CreateVM
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant_ovirt3::action::create_vm")
          @app = app
        end

        def call(env)
          # Get config.
          config = env[:machine].provider_config

          # Gather some info about domain
          name = (config.name.nil? ? env[:domain_name] : config.name)[0,80]
          console = config.console
          cpus = config.cpus
          memory_guaranteed_size = config.memory_guaranteed ? config.memory_guaranteed*1024 : nil
          quota = config.quota
          memory_size = config.memory*1024
          connect_timeout = config.connect_timeout
          user_data = config.user_data ?
            Base64::encode64(config.user_data) :
            nil

          # Get cluster
          if config.cluster == nil
            cluster = env[:ovirt_compute].clusters.first
          else
            cluster = OVirtProvider::Util::Collection.find_matching(
              env[:ovirt_compute].clusters.all, config.cluster)
          end
          raise Errors::NoClusterError if cluster == nil
          # TODO fill env also with other ovirtoptions.
          env[:ovirt_cluster] = cluster

          # Get template
          template = env[:ovirt_compute].templates.all.find_all { |t|
            t.id == config.template or t.name == config.template
          }
          .sort_by { |t| t.raw.version.version_number.to_i }.reverse
          .find { |t|
            v = t.raw.version
            cv = config.template_version
            cv.nil? or (cv.to_i == v.version_number.to_i or cv == v.version_name)
          }
          if template == nil
            raise Errors::NoTemplateError,
              :template_name => config.template
          end
          ver = template.raw.version
          if !ver.version_name.nil? and !ver.version_name.empty?
            version_string = "#{ver.version_name} (#{ver.version_number.to_i})"
          else
            version_string = "#{ver.version_number.to_i}"
          end

          # Output the settings we're going to use to the user
          env[:ui].info(I18n.t("vagrant_ovirt3.creating_vm"))
          env[:ui].info(" -- Name:              #{name}")
          env[:ui].info(" -- Cpus:              #{cpus}")
          env[:ui].info(" -- Memory:            #{memory_size/1024}M")
          env[:ui].info(" -- Template:          #{template.name}")
          env[:ui].info(" -- Version:           #{version_string}")
          env[:ui].info(" -- Datacenter:        #{config.datacenter}")
          env[:ui].info(" -- Cluster:           #{cluster.name}")
          env[:ui].info(" -- Console:           #{console}")
          if memory_guaranteed_size
            env[:ui].info(" -- Memory Guaranteed: #{memory_guaranteed_size/1024}M")
          end
          if quota
            env[:ui].info(" -- Quota:           #{quota}")
          end
          if config.disk_size
            env[:ui].info(" -- Disk size:       #{config.disk_size}G")
          end
          if config.user_data
            env[:ui].info(" -- User data:\n#{config.user_data}")
          end

          # Create oVirt VM.
          attr = {
              :name               => name,
              :cores              => cpus,
              :memory             => memory_size*1024,
              :cluster            => cluster.id,
              :template           => template.id,
              :display            => {:type => console },
              :user_data          => user_data,
              :quota              => quota,
              :memory_guaranteed  => memory_guaranteed_size,
          }

          begin
            server = env[:ovirt_compute].servers.create(attr)
          rescue OVIRT::OvirtException => e
            raise Errors::FogCreateServerError,
              :error_message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          # Wait till all volumes are ready.
          env[:ui].info(I18n.t("vagrant_ovirt3.wait_for_ready_vm"))
          for i in 0..connect_timeout
            ready = true
            server = env[:ovirt_compute].servers.get(env[:machine].id.to_s)
            server.volumes.each do |volume|
              if volume.status != 'ok'
                ready = false
                break
              end
            end
            if env[:machine].state.id != :down
              ready = false
            end
            break if ready
            sleep 2
          end

          if not ready
            raise Errors::WaitForReadyVmTimeout
          end

          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          # Undo the import
          env[:ui].info(I18n.t("vagrant_ovirt3.error_recovering"))
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
