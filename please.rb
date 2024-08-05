# please.rb

require 'readline'
require 'json'
require 'date'
require 'csv'

# Class representing a single todo list
class List
  attr_accessor :name, :id, :entries

  @@next_id = 1

  def initialize(name)
    @name = name
    @id = @@next_id
    @@next_id += 1
    @entries = []
  end
end

# Class representing a single entry in a todo list
class Entry
  attr_accessor :id, :name, :date, :text

  @@next_id = 1

  def initialize(name, text)
    @id = @@next_id
    @@next_id += 1
    @name = name
    @date = Date.today.to_s
    @text = text
  end
end

class Please
  VALID_COMMANDS = %w[me add delete wife show print move save quit exit drink boards set create use].map(&:downcase)
  ADD_SUBCOMMANDS = %w[daily weekly monthly redo].map(&:downcase)

  def initialize
    @lists = { "default" => List.new("default") }
    @commands = {}
    @wife_mode = false
    @default_board_id = @lists["default"].id
    @file_name = "please.json"
    load_data
  end

  def load_data
    if File.exist?(@file_name)
      data = JSON.parse(File.read(@file_name))
      @lists = data.transform_values do |list_data|
        list = List.new(list_data['name'])
        list.instance_variable_set(:@id, list_data['id'])
        list.entries = list_data['entries'].map do |entry_data|
          entry = Entry.new(entry_data['name'], entry_data['text'])
          entry.instance_variable_set(:@id, entry_data['id'])
          entry
        end
        list
      end
      List.class_variable_set(:@@next_id, @lists.values.map(&:id).max.to_i + 1)
      Entry.class_variable_set(:@@next_id, @lists.values.flat_map(&:entries).map(&:id).max.to_i + 1)
      @default_board_id = @lists["default"].id
    end
  end

  def parse_arguments(args)
    return if args.empty?

    command_input = args.shift
    command = find_command(command_input.downcase, VALID_COMMANDS)

    if command.nil?
      puts "Unknown command: #{command_input}"
      return
    end

    subcommands = []
    parameters = {}

    case command
    when 'add'
      parameters['name'] = args.join('') if args.size == 1
    when 'move'
      id = args.shift
      parameters['id'] = id.to_i
      args.each do |arg|
        key, value = arg.split("=")
        parameters[key.downcase] = value
      end
    when 'set'
      args.each do |arg|
        key, value = arg.split("=")
        parameters[key.downcase] = value
      end
    when 'create'
      args.each do |arg|
        key, value = arg.split("=")
        parameters[key.downcase] = value
      end
    else
      args.each do |arg|
        if arg.include?("=")
          key, value = arg.split("=")
          parameters[key.downcase] = value
        else
          subcommands << find_command(arg.downcase, VALID_COMMANDS)
        end
      end
    end

    @commands[command] = { subcommands: subcommands.compact, parameters: parameters }
    execute_command(command)
  end

  def find_command(input, valid_list)
    return nil if input.nil? || valid_list.nil?

    matches = valid_list.select { |cmd| cmd.start_with?(input) }
    return matches.first if matches.size == 1

    nil
  end

  def execute_command(command)
    if @wife_mode && command != 'drink'
      puts "yes"
      return
    end

    method_name = "do_#{command}"
    if respond_to?(method_name, true)
      send(method_name, @commands[command])
    else
      puts "Unknown command: #{command}"
    end
  end

  def start_interactive
    while input = Readline.readline('please> ', true)
      args = CSV::parse_line(input, col_sep: ' ')
      parse_arguments(args)
    end
  end

  private

  def get_list_by_id(id)
    @lists.values.find { |list| list.id == id }
  end

  def do_me(cmd)
    puts "Executing 'me' with #{cmd}"
  end

  def do_add(cmd)
    puts "Executing 'add' with #{cmd}"
    subcommand = cmd[:subcommands].first
    name = cmd[:parameters]['name'] || "Unnamed"
    text = cmd[:parameters]['text'] || "No text provided"
    times = cmd[:parameters]['times'] || 1

    which_board = get_list_by_id(@default_board_id).name
    puts "Adding entry to list: #{which_board}"
    case subcommand
    when 'redo'
      times.to_i.times do
        entry = Entry.new(name, text)
        @lists[which_board].entries << entry
      end
    else
      entry = Entry.new(name, text)
      @lists[which_board].entries << entry
    end
    puts "Added entry to current list"
  end

  def do_delete(cmd)
    puts "Executing 'delete' with #{cmd}"
  end

  def do_create(cmd)
    list_name = cmd[:parameters]['name']
    @lists[list_name] = List.new(list_name)
    puts "Created list with name: #{list_name}"
  end

  def do_wife(cmd)
    @wife_mode = true
    puts "Wife mode activated"
  end

  def do_drink(cmd)
    @wife_mode = false
    puts "Thank you"
  end

  def do_show(cmd)
    board_param = cmd[:parameters]['board']
    list = if board_param
             @lists.values.find { |l| l.id == board_param.to_i || l.name.downcase == board_param.downcase }
           else
             @lists.values.find { |l| l.id == @default_board_id }
           end

    if list.nil?
      puts "List not found with id or name: #{board_param}"
    else
      list.entries.each do |entry|
        puts "ID: #{entry.id}, Name: #{entry.name}, Date: #{entry.date}, Text: #{entry.text}"
      end
    end
  end

  def do_print(cmd)
    puts "Executing 'print' with #{cmd}"
  end

  def do_move(cmd)
    id = cmd[:parameters]['id']
    from_list = @lists.values.find { |l| l.id == (cmd[:parameters]['from'] ? cmd[:parameters]['from'].to_i : @default_board_id) }
    to_list = @lists.values.find { |l| l.id == cmd[:parameters]['to'].to_i }

    if to_list.nil?
      puts "Missing or invalid 'to' parameter for move command"
      return
    end

    if from_list.nil?
      puts "List not found: #{from_list}"
      return
    end

    entry = from_list.entries.find { |e| e.id == id }

    if entry.nil?
      puts "Entry not found with id: #{id}"
    else
      from_list.entries.delete(entry)
      to_list.entries << entry
      puts "Moved entry with id #{id} from #{from_list.name} to #{to_list.name}"
    end
  end

  def do_save(cmd)
    file_name = @file_name
    data = @lists.transform_values do |list|
      {
        name: list.name,
        id: list.id,
        entries: list.entries.map do |entry|
          {
            id: entry.id,
            name: entry.name,
            date: entry.date,
            text: entry.text
          }
        end
      }
    end
    File.write(file_name, JSON.pretty_generate(data))
    puts "Data saved to #{file_name}"
  end

  def do_exit(cmd)
    do_save(cmd)
    puts "Exiting program"
    exit
  end

  def do_quit(cmd)
    puts "Quitting program"
    exit
  end

  def do_boards(cmd)
    @lists.each do |name, list|
      puts "Name: #{list.name}, ID: #{list.id}"
    end
  end

  def do_set(cmd)
    parameters = cmd[:parameters]

    if parameters['board']
      @default_board_id = parameters['board'].to_i
      puts "Default board set to #{@default_board_id}"
    end

    if parameters['file']
      @file_name = parameters['file']
      puts "File name set to #{@file_name}"
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    please = Please.new
    please.start_interactive
  else
    please = Please.new
    please.parse_arguments(ARGV)
  end
end
