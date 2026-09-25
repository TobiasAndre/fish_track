class AddObjectSnapshotsToActivityLogs < ActiveRecord::Migration[8.1]
  def change
    # Estado do objeto antes e depois da ação (create: só depois; destroy: só antes).
    add_column :activity_logs, :object_before, :jsonb
    add_column :activity_logs, :object_after, :jsonb
  end
end
