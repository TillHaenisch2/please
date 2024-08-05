# test_please.rb

require 'minitest/autorun'
require_relative 'please'

class PleaseTest < Minitest::Test
  def setup
    @please = Please.new
  end

  def test_add_entry_to_default_list
    @please.parse_arguments(['add', 'daily', 'name=shopping', 'Buy milk'])
    assert_equal 1, @please.instance_variable_get(:@lists)['default'].entries.size
    entry = @please.instance_variable_get(:@lists)['default'].entries.first
    assert_equal 'shopping', entry.name
    assert_equal 'Buy milk', entry.text
  end

  def test_show_entries_in_default_list
    @please.parse_arguments(['add', 'daily', 'name=shopping', 'Buy milk'])
    output = capture_io { @please.parse_arguments(['show']) }.first
    assert_match(/ID: \d+, Name: shopping, Date: \d{4}-\d{2}-\d{2}, Text: Buy milk/, output)
  end

  def test_move_entry_between_lists
    @please.parse_arguments(['add', 'daily', 'name=shopping', 'Buy milk'])
    @please.parse_arguments(['add', 'daily', 'name=work', 'Complete project'])
    @please.parse_arguments(['boards'])
    default_list = @please.instance_variable_get(:@lists)['default']
    new_list = List.new('new_list')
    @please.instance_variable_get(:@lists)['new_list'] = new_list
    entry_id = default_list.entries.first.id
    @please.parse_arguments(['move', entry_id.to_s, 'to=new_list'])
    assert_equal 1, new_list.entries.size
    assert_equal 'shopping', new_list.entries.first.name
    assert_equal 1, default_list.entries.size
    assert_equal 'work', default_list.entries.first.name
  end

  def test_set_default_board
    new_list = List.new('new_list')
    @please.instance_variable_get(:@lists)['new_list'] = new_list
    @please.parse_arguments(['set', 'board=2'])
    assert_equal new_list.id, @please.instance_variable_get(:@default_board_id)
  end

  def test_save_and_load_data
    @please.parse_arguments(['add', 'daily', 'name=shopping', 'Buy milk'])
    @please.parse_arguments(['save'])
    new_please = Please.new
    new_please.load_data
    assert_equal 1, new_please.instance_variable_get(:@lists)['default'].entries.size
    entry = new_please.instance_variable_get(:@lists)['default'].entries.first
    assert_equal 'shopping', entry.name
    assert_equal 'Buy milk', entry.text
  end

  private

  def capture_io
    require 'stringio'
    old_stdout = $stdout
    old_stderr = $stderr
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    yield
    return out.string, err.string
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end

