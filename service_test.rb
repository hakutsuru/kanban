$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'minitest/autorun'
require 'service'


describe Service do
  before do
    Redis.new.flushdb
  end

  it "should allow predictable operations-per-second" do
    service_period = 2
    service_limit = 32
    stop_time = Time.now.to_i + (2 * service_period)
    operations_count = 0
    while Time.now.to_i < stop_time do
      if (Service.service_kanban(false,service_limit,service_period))
        operations_count += 1
      end
    end
    operations_count.must_be :<=, (2 * service_limit)
  end

  it "should stall operation until capacity available" do
    # not a standard kanban test (keep commented out)
    # to avoid frustrating delays during testing
    service_period = 8
    service_limit = 8
    # consume available slots
    service_limit.times do |iteration|
      Service.service_kanban(false,service_limit,service_period)
    end
    stop_time = Time.now.to_i + (service_period + 2)
    operations_count = 0
    while Time.now.to_i < stop_time do
      if (Service.service_kanban(true,service_limit,service_period))
        operations_count += 1
      end
    end
    # consider, if we claim each kanban for 8 seconds
    # when polling for enough seconds, we should
    # have consumed all slots *once* and
    # then wait for one to get free...
    operations_count.must_equal (service_limit + 1)
  end

end
