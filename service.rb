require 'rubygems'
require 'redis'
require 'date'


class Service
  SERVICE_API_Limit     = 7 # operations per minute (~10,000/day)
  SERVICE_API_Period    = 60 # seconds for API Limit
  SERVICE_Redis_Space   = "coolapi:"
  SERVICE_Kanban_Key    = "#{SERVICE_Redis_Space}kanban:"

  # your redis handle would likely be configured
  # during rails initialization... and, um, if
  # using Passenger, get new connection for
  # every process
  @redis = Redis.new

  def self.service_kanban(wait_for_slot = true,
                          limit_ops = SERVICE_API_Limit,
                          limit_period = SERVICE_API_Period)
    # we should limit our access to "service" api...
    wait_count = 0
    scans_per_period = 5
    wait_delay = limit_period/scans_per_period
    wait_limit = 16 * limit_period
    # use wait_delay to tune polling work
    # required while waiting for free kanban
    service_api_kanban = SERVICE_Kanban_Key
    begin
      limit_ops.times do |iteration|
        card_number = iteration.to_s
        service_kanban = service_api_kanban + card_number
        unless @redis.exists(service_kanban)
          @redis.setex(service_kanban, limit_period, Time.now.to_s)
          return true # allow operation to proceed
        end
      end
      if (wait_for_slot)
        # check for open slot every wait_delay
        # remember limit_period is seconds
        sleep wait_delay
      end
      wait_count += wait_delay
    end while (wait_for_slot && ( wait_count < wait_limit ))
    if wait_for_slot
      # you might wish to log this...
      # Rails.logger.info "Service Kanban - wait violated, task dropped"
    end
    return false # no available kanban
  end

end


if $0 == __FILE__

  puts ""
  puts "~ Rate Limiting - Waiting for Kanban"
  puts "~ 60 seconds - limit of 2 operations per 10 seconds"
  time_stop = Time.now + 60
  while Time.now < time_stop do
    kanban_found = Service.service_kanban(true, 2, 10)
    if kanban_found
      puts DateTime.now.strftime('%Y-%m-%d %H:%M:%S.%L')
    end
  end
  Redis.new.flushdb
  
  puts ""
  puts "~ Rate Limiting - Dropping Tasks (Do Not Wait for Kanban)"
  puts "~ 60 seconds - limit of 2 operations per 10 seconds"
  drop_count = 0
  time_stop = Time.now + 60
  while Time.now < time_stop do
    kanban_found = Service.service_kanban(false, 2, 10)
    if kanban_found
      if drop_count > 0
        puts "  [" + drop_count.to_s + " requests skipped]"
        drop_count = 0
      end
      puts DateTime.now.strftime('%Y-%m-%d %H:%M:%S.%L')
    else
      drop_count += 1
    end
  end
  
end
