class AddBackupEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :backup_email, :string, default: nil, index: true
  end
end
