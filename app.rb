require 'sinatra'
require 'sinatra/json'
require 'json'

# Configure Sinatra
set :views, File.dirname(__FILE__) + '/app/views'
enable :sessions

# Game Logic
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

  # Bot move with difficulty levels
  def self.bot_move(board, bot_symbol, difficulty = 'normal')
    player_symbol = bot_symbol == 'X' ? 'O' : 'X'
    
    case difficulty
    when 'easy'
      easy_move(board)
    when 'normal'
      normal_move(board, bot_symbol, player_symbol)
    when 'hard'
      hard_move(board, bot_symbol, player_symbol)
    else
      normal_move(board, bot_symbol, player_symbol)
    end
  end

  private
  # Easy: Completely random moves
  def self.easy_move(board)
    available = board.each_index.select { |i| board[i].nil? }
    available.sample
  end

  # Normal: Smart strategy
  def self.normal_move(board, bot_symbol, player_symbol)
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
  # Hard: Minimax algorithm (unbeatable)
  def self.hard_move(board, bot_symbol, player_symbol)
    # Use minimax to find optimal move - pass a COPY of the board
    result = minimax(board.dup, bot_symbol, bot_symbol, player_symbol)
    result[:index]
  end
  def self.minimax(board, current_player, bot_symbol, player_symbol)
    # Terminal states
    result = check_winner(board)
    if result
      if result[:winner] == bot_symbol
        return { score: 10 }
      elsif result[:winner] == player_symbol
        return { score: -10 }
      else
        return { score: 0 }
      end
    end
    # Generate possible moves
    moves = []
    board.each_with_index do |cell, index|
      if cell.nil?
        # Try this move on a COPY of the board
        new_board = board.dup
        new_board[index] = current_player
        
        # Get score for this move
        result = minimax(new_board, 
                        current_player == bot_symbol ? player_symbol : bot_symbol,
                        bot_symbol, 
                        player_symbol)
        score = result[:score]
        
        moves << { index: index, score: score }
      end
    end  
    # Choose best move
    best_move = nil
    if current_player == bot_symbol
      best_score = -1000
      moves.each do |move|
        if move[:score] > best_score
          best_score = move[:score]
          best_move = move
        end
      end
    else
      best_score = 1000
      moves.each do |move|
        if move[:score] < best_score
          best_score = move[:score]
          best_move = move
        end
      end
    end
    
    best_move || { index: nil, score: 0 }
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
# Helper method to make bot move
def make_bot_move
  board = session[:board]
  bot_symbol = session[:bot_symbol]
  difficulty = session[:difficulty]
  
  bot_index = TicTacToe.bot_move(board, bot_symbol, difficulty)
  if bot_index
    board[bot_index] = bot_symbol
    session[:board] = board
    result = TicTacToe.check_winner(board)
    
    if result
      session[:winner] = result[:winner]
      session[:scores][result[:winner]] += 1 if result[:winner] != 'draw'
    else
      session[:current_player] = session[:player_symbol]
    end
  end
end

# Initialize game state in session if not present
before do
  session[:board] ||= Array.new(9, nil)
  session[:current_player] ||= 'X'
  session[:scores] ||= { 'X' => 0, 'O' => 0 }
  session[:winner] ||= nil
  session[:game_mode] ||= '2player'
  session[:difficulty] ||= 'normal'
  # Make sure player_symbol and bot_symbol are always set
  session[:player_symbol] ||= 'X'
  session[:bot_symbol] ||= session[:player_symbol] == 'X' ? 'O' : 'X'
end

# Routes
get '/' do
  erb :index
end

get '/game' do
  # Set game mode if provided in params
  if params[:mode]
    session[:board] = Array.new(9, nil)
    session[:winner] = nil
    session[:game_mode] = params[:mode]
    session[:difficulty] = params[:difficulty] || 'normal'
    
    # Set player/bot symbols
    if params[:mode] == 'bot'
      session[:player_symbol] = params[:player_symbol] || 'X'
      session[:bot_symbol] = session[:player_symbol] == 'X' ? 'O' : 'X'
      
      # Set initial player based on who goes first (X always goes first)
      if session[:player_symbol] == 'X'
        session[:current_player] = 'X'  # Player X goes first
      else
        session[:current_player] = 'X'  # Bot (X) goes first when player is O
        # Make bot's first move immediately
        make_bot_move()
      end
    else
      # For 2-player mode, just set basic values
      session[:player_symbol] = 'X'
      session[:bot_symbol] = 'O'
      session[:current_player] = 'X'
      # NO bot moves in 2-player mode!
    end
  end
  
  # Only make bot move in bot mode!
  if session[:game_mode] == 'bot' && 
     !session[:winner] && 
     session[:current_player] == session[:bot_symbol]
    make_bot_move()
  end
  
  @board = session[:board]
  @current_player = session[:current_player]
  @scores = session[:scores]
  @winner = session[:winner]
  @game_mode = session[:game_mode]
  @difficulty = session[:difficulty]
  @player_symbol = session[:player_symbol]
  @bot_symbol = session[:bot_symbol]
  erb :game
end

# Handle a move (cell index 0-8)
get '/move/:index' do
  index = params[:index].to_i
  board = session[:board]
  player = session[:current_player]
  game_mode = session[:game_mode]
  difficulty = session[:difficulty]
  player_symbol = session[:player_symbol]
  bot_symbol = session[:bot_symbol]

  # Ignore if cell already taken or game over
  if board[index] || session[:winner]
    redirect '/game'
  end

  # Make the move
  board[index] = player
  session[:board] = board
  result = TicTacToe.check_winner(board)
  
  if result
    session[:winner] = result[:winner]
    session[:scores][result[:winner]] += 1 if result[:winner] != 'draw'
  else
    # Switch to next player
    session[:current_player] = player == 'X' ? 'O' : 'X'
    
    # Only make bot move in bot mode and ONLY if it's now bot's turn
    # This prevents double moves
    if game_mode == 'bot' && 
       session[:current_player] == bot_symbol && 
       !session[:winner]
      make_bot_move()
    end
  end
  redirect '/game'
end

# Reset game - fix to maintain proper starting player
post '/api/reset' do
  content_type :json
  session[:board] = Array.new(9, nil)
  session[:winner] = nil
  
  # Set current player based on game mode
  if session[:game_mode] == 'bot'
    if session[:player_symbol] == 'X'
      session[:current_player] = 'X'  # Player X goes first
    else
      session[:current_player] = 'X'  # Bot (X) goes first when player is O
      # Make bot's first move immediately
      make_bot_move()
    end
  else
    session[:current_player] = 'X'  # X always goes first in 2-player
  end
  
  json({ status: 'success' })
end