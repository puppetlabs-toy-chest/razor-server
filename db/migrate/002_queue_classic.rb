require_relative '../../lib/razor/queue_classic'

Sequel.migration do
  # QC maintains transactionally just fine on it's own, thanks.  Just make
  # sure you don't do anything other than QC stuff in this migration.
  no_transaction

  up do
    synchronize do |conn|
      QC::Conn.connection = conn
      QC::Setup.create
    end
  end

  down do
    synchronize do |conn|
      QC::Conn.connection = conn
      QC::Setup.drop
    end
  end
end
