require 'sinatra'
require 'sinatra/json'
require 'json'

# Configure Sinatra
set :views, File.dirname(__FILE__) + '/app/views'
enable :sessions

# Game Logic
class TicTacToe
  WINNING_COMBOS = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], # rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], # columns
    [0, 4, 8], [2, 4, 6]              # diagonals
  ].freeze

  def self.check_winner(board)
    # Check for winning combinations
    WINNING_COMBOS.each do |combo|
      if board[combo[0]] && board[combo[0]] == board[combo[1]] && board[combo[1]] == board[combo[2]]
        return { winner: board[combo[0]], winning_combo: combo }
      end
    end

    # Check for draw (all cells filled)
    return { winner: 'draw' } if board.none?(nil)

    # Game still in progress
    nil
  end

  # Simple bot AI
  def self.bot_move(board, bot_symbol)
    player_symbol = bot_symbol == 'X' ? 'O' : 'X'
    
    # Strategy 1: Win if possible
    move = find_winning_move(board, bot_symbol)
    return move if move
    
    # Strategy 2: Block opponent from winning
    move = find_winning_move(board, player_symbol)
    return move if move
    
    # Strategy 3: Take center if available
    return 4 if board[4].nil?
    
    # Strategy 4: Take a corner
    corners = [0, 2, 6, 8]
    available_corners = corners.select { |i| board[i].nil? }
    return available_corners.sample if available_corners.any?
    
    # Strategy 5: Take any available spot
    board.each_with_index do |cell, index|
      return index if cell.nil?
    end
    
    nil
  end

  def self.find_winning_move(board, symbol)
    WINNING_COMBOS.each do |combo|
      values = combo.map { |i| board[i] }
      if values.count(symbol) == 2 && values.count(nil) == 1
        return combo[values.index(nil)]
      end
    end
    nil
  end
end

# Initialize game state in session if not present
before do
  session[:board] ||= Array.new(9, nil)
  session[:current_player] ||= 'X'
  session[:scores] ||= { 'X' => 0, 'O' => 0 }
  session[:winner] ||= nil
  session[:game_mode] ||= '2player'
end

# Routes
get '/' do
  erb :index
end

get '/game' do
  # Set game mode if provided in params
  if params[:mode]
    session[:board] = Array.new(9, nil)
    session[:current_player] = 'X'
    session[:winner] = nil
    session[:game_mode] = params[:mode]
  end
  
  @board = session[:board]
  @current_player = session[:current_player]
  @scores = session[:scores]
  @winner = session[:winner]
  @game_mode = session[:game_mode]
  erb :game
end

# Handle a move (cell index 0-8)
get '/move/:index' do
  index = params[:index].to_i
  board = session[:board]
  player = session[:current_player]
  game_mode = session[:game_mode]

  # Ignore if cell already taken or game over
  if board[index] || session[:winner]
    redirect '/game'
  end

  # In bot mode, only allow player X to make moves
  if game_mode == 'bot' && player == 'O'
    redirect '/game'
  end

  # Make player move
  board[index] = player
  session[:board] = board
  result = TicTacToe.check_winner(board)
  
  if result
    session[:winner] = result[:winner]
    session[:scores][result[:winner]] += 1 if result[:winner] != 'draw'
  else
    session[:current_player] = player == 'X' ? 'O' : 'X'
    
    # If bot mode and it's now the bot's turn, make bot move
    if game_mode == 'bot' && session[:current_player] == 'O' && !session[:winner]
      bot_index = TicTacToe.bot_move(board, 'O')
      if bot_index
        board[bot_index] = 'O'
        session[:board] = board
        bot_result = TicTacToe.check_winner(board)
        
        if bot_result
          session[:winner] = bot_result[:winner]
          session[:scores][bot_result[:winner]] += 1 if bot_result[:winner] != 'draw'
        else
          session[:current_player] = 'X'
        end
      end
    end
  end
  redirect '/game'
end

# Reset game
post '/api/reset' do
  content_type :json
  session[:board] = Array.new(9, nil)
  session[:current_player] = 'X'
  session[:winner] = nil
  # Keep the game mode for next game
  json({ status: 'success' })
end
