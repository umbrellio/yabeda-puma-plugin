require 'yabeda/puma/plugin.rb'

Puma::Plugin.create do
  def start(launcher)
    clustered = (launcher.options[:workers] || 0) > 0

    control_url = launcher.options[:control_url]
    raise StandardError, "Puma control app is not activated" if control_url == nil

    Yabeda::Puma::Plugin.tap do |puma|
      puma.control_url = control_url
      puma.control_auth_token = launcher.options[:control_auth_token]
    end

    Yabeda.configure do
      group :puma

      gauge :backlog, tags: %i[index], comment: 'Number of established but unaccepted connections in the backlog', aggregation: :max
      gauge :running, tags: %i[index], comment: 'Number of running worker threads', aggregation: :max
      gauge :pool_capacity, tags: %i[index], comment: 'Number of allocatable worker threads', aggregation: :max
      gauge :busy_threads, tags: %i[index], comment: 'Maximum number of busy threads', aggregation: :max
      gauge :max_threads, tags: %i[index], comment: 'Maximum number of worker threads', aggregation: :max

      if clustered
        gauge :workers, comment: 'Number of configured workers', aggregation: :max
        gauge :booted_workers, comment: 'Number of booted workers', aggregation: :max
        gauge :old_workers, comment: 'Number of old workers', aggregation: :max
      end

      collect do
        require 'yabeda/puma/plugin/statistics/fetcher'
        stats = Yabeda::Puma::Plugin::Statistics::Fetcher.call
        require 'yabeda/puma/plugin/statistics/parser'
        Yabeda::Puma::Plugin::Statistics::Parser.new(clustered: clustered, data: stats).call.each do |item|
          send("puma_#{item[:name]}").set(item[:labels], item[:value])
        end
      end
    end
  end
end
