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
end

# Initialize game state in session if not present
before do
  session[:board] ||= Array.new(9, nil)
  session[:current_player] ||= 'X'
  session[:scores] ||= { 'X' => 0, 'O' => 0 }
  session[:winner] ||= nil
end

# Routes
get '/' do
  erb :index
end

get '/game' do
  @board = session[:board]
  @current_player = session[:current_player]
  @scores = session[:scores]
  @winner = session[:winner]
  erb :game
end

# Handle a move (cell index 0-8)
get '/move/:index' do
  index = params[:index].to_i
  board = session[:board]
  player = session[:current_player]

  # Ignore if cell already taken or game over
  if board[index] || session[:winner]
    redirect '/game'
  end

  board[index] = player
  session[:board] = board
  result = TicTacToe.check_winner(board)
  
  if result
    session[:winner] = result[:winner]
    session[:scores][result[:winner]] += 1 if result[:winner] != 'draw'
  else
    session[:current_player] = player == 'X' ? 'O' : 'X'
  end
  redirect '/game'
end

# Reset game
post '/api/reset' do
  content_type :json
  session[:board] = Array.new(9, nil)
  session[:current_player] = 'X'
  session[:winner] = nil
  json({ status: 'success' })
end
