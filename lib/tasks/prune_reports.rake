namespace :reports do
  desc 'Prune old reports from the databases, will print help if run without arguments'
  task :prune => :environment do
    units = {
      'min' => '60',
      'hr' => '3600',
      'day' => '86400',
      'wk' => '604800',
      'mon' => '2592000',
      'yr' => '31536000'
    }
    known_units = units.keys.join(',')

    usage = %{
EXAMPLE:
  # Prune records upto 1 month old:
  rake reports:prune upto=1 unit=mon

UNITS:
  Valid units of time are: #{known_units}
    }.strip

    unless ENV['upto'] || ENV['unit']
      puts usage
      exit 0
    end

    errors = []

    if ENV['upto'] =~ /^\d+$/
      upto = ENV['upto'].to_i
    else
      errors << "You must specify how far up you want to prune as an integer, e.g.: upto={some integer}" \
    end

    if unit = ENV['unit']
      unless units.has_key?(unit)
        errors << "I don't know that unit. Valid units are: #{known_units}" \
      end
    else
      errors << "You must specify the unit of time, .e.g.: unit={#{known_units}}" \
    end

    if errors.present?
      puts errors.map { |error| "ERROR: #{error}" }
      puts
      puts usage
      exit 1
    end

    cutoff = Time.now.gmtime - (upto * units[unit].to_i)
    puts "Deleting reports before #{cutoff}..."

    affected_nodes = Node.find(:all, :include => 'reports', :conditions => ['reports.time < ?', cutoff])

    # the database does cascading deletes for us on dependent records
    deleted_count = Report.delete_all(['time < ?', cutoff])

    # In case the last report was deleted we need to update the node
    # This normally runs after report destroy as a callback
    # but we're doing delete since it's a LOT faster
    affected_nodes.each(&:find_and_assign_last_apply_report)
    affected_nodes.each(&:find_and_assign_last_inspect_report)

    puts "Deleted #{deleted_count} reports."
  end

  namespace :prune do
    desc 'Delete orphaned records whose report has already been deleted'
    task :orphaned => :environment do
      require "#{RAILS_ROOT}/lib/progress_bar"

      report_dependent_deletion = 'report_id not in (select id from reports)'

      orphaned_tables = ActiveSupport::OrderedHash[
        Metric,         report_dependent_deletion,
        ReportLog,      report_dependent_deletion,
        ResourceStatus, report_dependent_deletion,
        ResourceEvent, 'resource_status_id not in (select id from resource_statuses)'
      ]

      puts "Going to delete orphaned records from #{orphaned_tables.keys.map(&:table_name).join(', ')}\n"

      orphaned_tables.each do |model, deletion_where_clause|
        puts "Preparing to delete from #{model.table_name}"
        start_time     = Time.now
        deletion_count = model.count(:conditions => deletion_where_clause)

        puts "#{start_time.to_s(:db)}: Deleting #{deletion_count} orphaned records from #{model.table_name}"
        pbar = ProgressBar.new('Deleting', deletion_count, STDOUT)

        # Improved query by Martin Langhoff
        ActiveRecord::Base.connection.execute(
          "delete #{model.table_name} from #{model.table_name} left join reports on reports.id=#{model.table_name}.report_id WHERE reports.id is null"
        )

        pbar.finish
        puts
      end
    end
  end
end
