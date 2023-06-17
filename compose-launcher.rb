call = lambda do |*args|
  require "open3"
  puts "> #{File.expand_path Dir.pwd}$ #{args}"
  output, status = Open3.capture2e *args
  unless status.exitstatus.zero?
    puts output
    abort "ERROR: cmd failed"
  end
  output
end

require "yaml"
require "json"
YAML.load_file("compose-launcher.yaml").each do |service|
  dir = "#{Dir.home}/_/.compose-launcher/#{service.fetch :dir}"
  if File.exist? dir
    # TODO: automatic branch witch if it was edited in config
    call["cd #{dir} && git stash && git pull && git stash apply"]
  else
    call["git clone git@github.com:#{service.fetch :repo}.git#{" -b #{service[:branch]}" if service[:branch]} #{dir}"]
  end
  Dir.chdir "#{dir}/#{service.fetch :cd}" do
    puts "cd #{Dir.pwd}"
    call[service[:pre]] if service.key? :pre
    compose_file = "#{"#{service[:compose]}." if service.key? :compose}docker-compose.yml"
    puts "compose file: #{compose_file}"
    until (
      ps = call["docker ps -a --no-trunc --format='{{json .}}'"].split("\n").map do |_|
        JSON.load(_).values_at *%w{ Names State }
      end.to_h
      YAML.load_file(compose_file).fetch("services").all? do |name, desc|
        "running" == ps[desc["container_name"] || name]
      end
    )
      call[service.fetch(:env, {}), "docker-compose -f #{compose_file}#{" --env-file #{ARGV[0]}" if ARGV[0]} up -d"]
    end
  end
end
