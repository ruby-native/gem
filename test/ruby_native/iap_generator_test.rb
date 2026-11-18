require "test_helper"
require "rails/generators/test_case"
require "generators/ruby_native/iap_generator"

class RubyNative::Generators::IapGeneratorTest < Rails::Generators::TestCase
  tests RubyNative::Generators::IapGenerator
  destination File.expand_path("../../tmp/iap_generator", __dir__)
  setup :prepare_destination

  def test_copies_both_migrations_with_increasing_numbers
    run_generator

    assert_migration "db/migrate/create_ruby_native_purchase_intents.rb"
    assert_migration "db/migrate/add_restored_transaction_id_to_ruby_native_purchase_intents.rb"

    create = migration_number("db/migrate/create_ruby_native_purchase_intents.rb")
    add_column = migration_number("db/migrate/add_restored_transaction_id_to_ruby_native_purchase_intents.rb")

    assert create < add_column,
      "The column migration must sort after the create, got #{create} then #{add_column}"
  end

  def test_turns_on_iap_routes_in_a_new_initializer
    run_generator

    assert_file "config/initializers/ruby_native.rb", /config\.iap_enabled = true/
  end

  def test_appends_to_an_existing_initializer
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    File.write(File.join(destination_root, "config/initializers/ruby_native.rb"), "RubyNative.configure { |config| config.screenshot_key = \"key\" }\n")

    run_generator

    assert_file "config/initializers/ruby_native.rb" do |content|
      assert_match(/screenshot_key/, content)
      assert_match(/config\.iap_enabled = true/, content)
    end
  end

  def test_rerunning_does_not_add_the_flag_twice
    run_generator
    run_generator

    assert_file "config/initializers/ruby_native.rb" do |content|
      assert_equal 1, content.scan("iap_enabled").size
    end
  end

  # Re-running on an app that already ran the create migration is the upgrade
  # path for the restored_transaction_id column.
  def test_rerunning_adds_only_the_missing_migration
    run_generator
    first_create = migration_file_name("db/migrate/create_ruby_native_purchase_intents.rb")
    FileUtils.rm(migration_file_name("db/migrate/add_restored_transaction_id_to_ruby_native_purchase_intents.rb"))

    run_generator

    assert_equal first_create, migration_file_name("db/migrate/create_ruby_native_purchase_intents.rb"),
      "The existing migration should be reported identical, not renumbered"
    assert_migration "db/migrate/add_restored_transaction_id_to_ruby_native_purchase_intents.rb"
  end

  # A tripwire, not a behavior test. Every app that has already run this
  # generator holds a byte-identical copy of this template, and re-running is how
  # such an app picks up migrations added later: Rails compares the two and only
  # calls it identical when they match exactly. Any edit here -- a comment, a
  # trailing newline -- makes it a conflict instead, which raises and aborts the
  # run before the newer migrations are copied, so upgrading apps get none of
  # them. To change the schema, add a template alongside it and copy that too.
  def test_the_create_migration_template_is_frozen
    path = File.expand_path(
      "../../lib/generators/ruby_native/templates/create_ruby_native_purchase_intents.rb", __dir__
    )

    assert_equal "f4c9967e25a041ba68294929280a865dd625a72771a12f892fc080a611f5f4d5",
      Digest::SHA256.hexdigest(File.binread(path)),
      "create_ruby_native_purchase_intents.rb changed. Read the comment above this test first."
  end

  private

  def migration_number(relative)
    File.basename(migration_file_name(relative)).to_i
  end
end
