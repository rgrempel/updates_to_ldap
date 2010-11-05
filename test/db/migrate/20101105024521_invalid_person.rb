class InvalidPerson < ActiveRecord::Migration
  def self.up
    create_table :invalid_people do |t|
      t.string   :first_name
      t.string   :last_name
      t.string   :email
      t.timestamps
    end
  end

  def self.down
    drop_table :invalid_people
  end
end
