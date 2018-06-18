class CreateConferenceSessions < ActiveRecord::Migration[5.0]
  def change
    create_table :conference_sessions do |t|
      t.text :data
      t.string :code
      t.string :conference_code
      t.timestamps
    end
    add_index :conference_sessions, [:code], :unique => true
  end
end
