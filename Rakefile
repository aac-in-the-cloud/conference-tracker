# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks
# Skip auto-running `yarn install` when running `rails assets:precompile`
Rake::Task["yarn:install"].clear
