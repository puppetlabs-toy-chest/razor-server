# -*- encoding: utf-8 -*-
require_relative '../initialize'
require_relative '../../razor'

# This is not technically compliant with the TorqueBox naming scheme, so see
# the end of the file for the magic that makes it happen. ;)
class Razor::ScheduledJobs::IPMI
  def run
    logger.info("checking for nodes that need a scheduled power state update")

    # Find all the nodes with an IPMI hostname, and schedule a background
    # update of their power state.  That is concurrency-limited through the
    # queue mechanism, so shouldn't overwhelm systems.
    #
    # This currently also uses the last update time in selection, to make sure
    # we don't poll too frequently in the event of server restarts, or users
    # messing with scheduling.
    #
    # @todo danielp 2013-12-05: this may well need to support variant
    # schedules in future, or only running a subset on each invocation,
    # or something.  For now this is enough, I think?
    nodes = Razor::Data::Node.where do |q|
      # @todo danielp 2013-12-05: when you want to adjust the minimum poll
      # interval, this is the place to do it.  We should make that externally
      # configurable at some point.
      timestamp = (Sequel.function(:NOW) - Sequel.lit("INTERVAL '4 minutes'"))
      q.|({:last_power_state_update_at => nil}, q.last_power_state_update_at < timestamp)
    end.exclude(:ipmi_hostname => nil)

    nodes.each do |node|
      logger.info("scheduling power state update of #{node.name}")
      node.publish 'update_power_state!'
    end
  end

  def on_error(exception)
    # @todo danielp 2013-12-05: other than logging, what should we do?
    logger.error("failed scheduling IPMI poll: #{exception}")
  end

  def logger
    @logger ||= TorqueBox::Logger.new(self.class)
  end
end

# This is to support the TorqueBox desired naming convention.
defined?(Razor::ScheduledJobs::Ipmi) or
  Razor::ScheduledJobs::Ipmi = Razor::ScheduledJobs::IPMI
