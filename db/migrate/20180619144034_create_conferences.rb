class CreateConferences < ActiveRecord::Migration[5.0]
  def change
    create_table :conferences do |t|
      t.string :name
      t.text :data
      t.string :code
      t.timestamps
    end
    add_index :conferences, [:code], :unique => true
  end
end
