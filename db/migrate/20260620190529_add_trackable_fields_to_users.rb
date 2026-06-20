class AddTrackableFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_ip
      t.string   :last_sign_in_ip
      t.integer :failed_attempts, default: 0, null: false
      t.string  :unlock_token
      t.datetime :locked_at
    end
    add_index :users, :unlock_token, unique: true if !index_exists?(:users, :unlock_token)
  end
end
