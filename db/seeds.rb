admin = User.find_or_initialize_by(email: ENV.fetch('ADMIN_EMAIL', 'admin@admin.com'))
admin.assign_attributes(
  password: ENV.fetch('ADMIN_PASSWORD', 'admin123456'),
  password_confirmation: ENV.fetch('ADMIN_PASSWORD', 'admin123456'),
  role: :admin,
  confirmed_at: Time.current
)
admin.save!
puts "Admin created: #{admin.email} (role: #{admin.role})"
