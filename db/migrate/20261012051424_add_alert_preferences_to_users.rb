class AddAlertPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :location_label, :string
    add_column :users, :latitude, :decimal, precision: 10, scale: 6
    add_column :users, :longitude, :decimal, precision: 10, scale: 6
    add_column :users, :timezone, :string
    add_column :users, :alert_time, :time
    add_column :users, :rain_threshold, :integer, default: 50, null: false
    add_column :users, :alerts_enabled, :boolean, default: true, null: false
    add_column :users, :last_alerted_at, :datetime

    add_index :users, :alerts_enabled
  end
end
