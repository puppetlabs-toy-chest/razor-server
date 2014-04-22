# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    # rename the enum type you want to change
    run %q{alter type command_status rename to command_status_temp}
    # create new type
    run %q{create type command_status as ENUM ('pending', 'running', 'failed', 'cancelled', 'finished')}
    # rename column which uses the enum type
    run %q{alter table commands rename column status to status_temp}
    # add new column of new type
    run %q{alter table commands add status command_status}
    # copy values to the new column
    run %q{update commands set status = status_temp::text::command_status}
    # set back to not-null
    run %q{alter table commands alter column status set not null}
    # remove old column and type
    run %q{alter table commands drop column status_temp}
    run %q{drop type command_status_temp}
  end

  down do
    extension(:constraint_validations)
    # rename the enum type you want to change
    run %q{alter type command_status rename to command_status_temp}
    # create new type
    run %q{create type command_status as ENUM ('pending', 'running', 'failed', 'finished')}
    # rename column which uses the enum type
    run %q{alter table commands rename column status to status_temp}
    # add new column of new type
    run %q{alter table commands add status command_status}
    # change problematic columns
    run %q{update commands set status_temp = 'failed' where status_temp = 'cancelled'}
    # copy values to the new column
    run %q{update commands set status = status_temp::text::command_status}
    # set back to not-null
    run %q{alter table commands alter column status set not null}
    # remove old column and type
    run %q{alter table commands drop column status_temp}
    run %q{drop type command_status_temp}
  end
end
