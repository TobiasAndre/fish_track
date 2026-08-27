class CreateReportShares < ActiveRecord::Migration[7.1]
  def change
    create_table :report_shares do |t|
      t.string :report_type, null: false
      t.jsonb :filters, null: false, default: {}
      t.string :share_token

      t.timestamps
    end

    add_index :report_shares, :share_token, unique: true
    add_index :report_shares, :report_type
  end
end
