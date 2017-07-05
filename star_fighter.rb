# Encoding: UTF-8

require 'rubygems'
require 'gosu'
require 'pry-byebug'

module ZOrder
  BACKGROUND, STARS, LASER, FIGHTER, PLAYER, UI = *0..5
end

class Player
  attr_reader :x, :y, :angle
  attr_accessor :hp, :enemy, :trail

  def initialize
    @image = Gosu::Image.new("media/starfighter.bmp")
    # @beep = Gosu::Sample.new("media/beep.wav")
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @hp = 5
    @enemy = nil
    @trail = []
    @hp_bar = Gosu::Image.load_tiles("media/blue_bar.bmp", 80, 133)
  end

  def alive?
    @hp > 0
  end

  def warp(x, y)
    @x, @y = x, y
  end

  def turn_left
    @angle -= 4.5
  end

  def turn_right
    @angle += 4.5
  end

  def accelerate
    @vel_x += Gosu.offset_x(@angle, 0.3)
    @vel_y += Gosu.offset_y(@angle, 0.3)
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x %= 1920
    @y %= 1080

    @vel_x *= 0.95
    @vel_y *= 0.95
  end

  def update_trail
    @trail << [@vel_x, @vel_y, @angle, Time.now]
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::PLAYER, @angle)
    if @hp > 0
      (0...@hp).each { |ind| @hp_bar[ind].draw((80 * ind), 10, ZOrder::UI) }
    end
  end
end

class Laser
  attr_reader :x, :y, :angle, :end_time, :owner, :contacted, :visible

  @@duration = 2.0

  def initialize(player)
    @x = player.x
    @y = player.y
    @angle = player.angle
    @vel_x = Gosu.offset_x(@angle, 7)
    @vel_y = Gosu.offset_y(@angle, 7)
    @end_time = Time.now + @@duration
    @owner = player
    @image = Gosu::Image.new("media/fighter_laser.png") if @owner.class == Player
    @image = Gosu::Image.new("media/player_laser.png") if @owner.class == Fighter
    @contacted = false
    @visible = true
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x %= 1920
    @y %= 1080
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::LASER, @angle)
  end

  def contact?(enemy)
    Gosu.distance(@x, @y, enemy.x, enemy.y) < 50
  end

  def contact!
    @contacted = true
    @visible = false
  end

  def self.lasers_charged?(lasers)
    (!lasers[0] || ((lasers.last.end_time - (@@duration - 0.25)) < Time.now))
  end
end

class Fighter < Player
  attr_reader :x, :y, :angle, :enemy
  attr_accessor :hp

  def initialize(player)
    @image = Gosu::Image.new("media/enemy_fighter.bmp")
    @enemy = player
    # @beep = Gosu::Sample.new("media/beep.wav")
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @hp = 5
    # @hp_bar = Gosu::Image.new("media/red_bar.jpg")
    @hp_bar = Gosu::Image.load_tiles("media/red_bar.bmp", 80, 133)
  end

  def move(trail)
    @x += trail[0]
    @y += trail[1]
    @x %= 1920
    @y %= 1080
    @angle = trail[2]
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::FIGHTER, @angle)
    if @hp > 0
      (0...@hp).each { |ind| @hp_bar[ind].draw(1500 + (80 * ind), 10, ZOrder::UI) }
    end
  end
end


class Tutorial < (Example rescue Gosu::Window)
  def initialize
    super 1920, 1080
    self.caption = "Tutorial Game"
    self.fullscreen = true
    @start_time = Time.now

    @background_image = Gosu::Image.new("media/big_space.png", :tileable => true)

    @player = Player.new
    @player.warp(960, 540)


    @fighter = Fighter.new(@player)
    @player.enemy = @fighter
    @fighter.warp(960, 540)


    @font = Gosu::Font.new(20)

    @player_lasers = Array.new
    @fighter_lasers = Array.new
  end

  def update
    if Gosu.button_down? Gosu::KB_LEFT or Gosu.button_down? Gosu::GP_LEFT
      @player.turn_left
    end
    if Gosu.button_down? Gosu::KB_RIGHT or Gosu.button_down? Gosu::GP_RIGHT
      @player.turn_right
    end
    if Gosu.button_down? Gosu::KB_UP or Gosu.button_down? Gosu::GP_BUTTON_0
      @player.accelerate
    end
    if (Gosu.button_down? Gosu::KB_SPACE) && Laser.lasers_charged?(@player_lasers) && @player.alive?
      @player_lasers.push(Laser.new(@player))
    end
    @player.move
    @player.update_trail
    @fighter.move(@player.trail.shift) if @player.trail[0][3] < (Time.now - 3)

    if (Time.now - 2) > @start_time && Laser.lasers_charged?(@fighter_lasers) && @fighter.alive?
      @fighter_lasers.push(Laser.new(@fighter))
    end

    # TODO @enemy.move
    for las in [@player_lasers, @fighter_lasers]
      if las
        las.each do |laser|
          if laser.contact?(laser.owner.enemy) && laser.visible
            #binding.pry
            laser.owner.enemy.hp -= 1
            laser.contact!
          end
          laser.move
        end
      end
      las.delete_if { |laser| (laser.end_time <= Time.now) }
    end
  end

  def draw
    @background_image.draw(0, 0, ZOrder::BACKGROUND)
    @player.draw if @player.alive?
    @fighter.draw if @fighter.alive?
    for las in [@player_lasers, @fighter_lasers]
      las.each { |laser| laser.draw if laser.visible }
    end
    if @player.hp > 0
      @font.draw("Player HP: #{@player.hp*20}", 10, 30, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
    else
      @font.draw("You are dead...", 10, 30, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
    end
    if @fighter.hp > 0
      @font.draw("Enemy HP: #{@fighter.hp*20}", 1790, 30, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
    else
      @font.draw("Computer is dead...", 1650, 30, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
    end

  end

  def button_down(id)
    if id == Gosu::KB_ESCAPE
      close
    else
      super
    end
  end
end

Tutorial.new.show if __FILE__ == $0
