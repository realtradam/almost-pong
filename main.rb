WindowWidth = 800
WindowHeight = 600
WindowTitle = 'Almost Ping Pong'
Rl.init_window(WindowWidth, WindowHeight, WindowTitle)
$frames = 0 # number of frames elapsed
$points = 0 # number of times a paddle was hit
$best_points = 0
$dead = false
$world_rec = Rl::Rectangle.new(0, 0, WindowWidth, WindowHeight)
include FECS

Cmp.new('Box', :obj)
Cmp.new('Position', :x, :y)
Cmp.new('Velocity', :x, :y)
Cmp.new('Paddle', :side)
Cmp.new('Ball')
Cmp.new('Color', :obj)
Cmp.new('EaseToward', :start, :finish, :time)

Ent.new(
  Cmp::Paddle.new(side: 'left'),
  Cmp::Box.new(obj: Rl::Rectangle.new(0,0,25,100)),
  Cmp::Position.new(x: 35, y: WindowHeight / 2),
  Cmp::Color.new(obj: Rl::Color.white)
)

Ent.new(
  Cmp::Paddle.new(side: 'right'),
  Cmp::Box.new(obj: Rl::Rectangle.new(0,0,25,100)),
  Cmp::Position.new(x: WindowWidth - 35, y: WindowHeight / 2),
  Cmp::Color.new(obj: Rl::Color.white)
)

Ent.new(
  Cmp::Ball.new,
  Cmp::Box.new(obj: Rl::Rectangle.new(0,0,25,25)),
  Cmp::Position.new(x: WindowWidth/2, y: WindowHeight/2),
  Cmp::Velocity.new(x: 2, y: 0),
  Cmp::Color.new(obj: Rl::Color.fire_brick)
)

def ease(start:, finish:, time:)
  distance = finish - start
  ((1 - (1 - time)**3) * distance) + start
end


Scn.new('Main')

# add all systems to a scene when they are created
Scn::Main.add(
  Sys.new('Input') do
    unless $dead
      if Rl.key_pressed? 32 # spacebar
        Scn::Main.add Sys::Move, Sys::Gravity
        Cmp::Ball.first.entity.component[Cmp::Velocity].y -= 4
      end
    end
    if Rl.key_pressed? 82
      $dead = false
      $points = 0
      Scn::Main.remove Sys::Move, Sys::Gravity
      ball = Cmp::Ball.first.entity

      # make ball go right when starting
      ball.component[Cmp::Velocity].x = ball.component[Cmp::Velocity].x.abs
      # reset gravity
      ball.component[Cmp::Velocity].y = 0

      # move to center
      ball.component[Cmp::Position].x = WindowWidth/2
      ball.component[Cmp::Position].y = WindowHeight/2

      # slide paddles to center
      Ent.group(Cmp::Paddle, Cmp::Position) do |paddle, position, entity|
        if !entity.components[Cmp::EaseToward].nil?
          entity.component[Cmp::EaseToward].delete
        end
        entity.add Cmp::EaseToward.new(start: position.y, finish: WindowHeight/2, time: 0)
      end
    end
  end,

  Sys.new('Gravity') do
    velocity = Cmp::Ball.first.entity.component[Cmp::Velocity]
    unless velocity.y > 15
      velocity.y += (1.0/6.0)
    end
  end,

  # moving a paddle to new position
  Sys.new('EaseToward') do
    Ent.group(Cmp::EaseToward, Cmp::Position) do |ease, position, entity|
      ease.time += Rl.frame_time * 2
      if ease.time > 1
        position.y = ease.finish
        ease.delete
      else
        position.y = ease(start: ease.start, finish: ease.finish, time: ease.time)
      end
    end
  end,

  Sys.new('Move') do
    ball_position = Cmp::Ball.first.entity.component[Cmp::Position]
    ball_velocity = Cmp::Ball.first.entity.component[Cmp::Velocity]
    ball_box = Cmp::Ball.first.entity.component[Cmp::Box]

    # center the box
    ball_box.obj.x = ball_position.x - (ball_box.obj.w/2)
    ball_box.obj.y = ball_position.y - (ball_box.obj.h/2)

    # used for checking if where the ball will be next frame
    future_ball = Rl::Rectangle.new(ball_box.obj.x + ball_velocity.x,
                                    ball_box.obj.y + ball_velocity.y,
                                    ball_box.obj.w,
                                    ball_box.obj.h)

    # used for checking if we are colliding a paddle directly from above/below
    future_ball_side = Rl::Rectangle.new(ball_box.obj.x,
                                         ball_box.obj.y + ball_velocity.y,
                                         ball_box.obj.w,
                                         ball_box.obj.h)

    # check if possible to move, bounce off else
    # iterate over all paddles that have a position and a box
    Ent.group(Cmp::Paddle, Cmp::Position, Cmp::Box) do |paddle, paddle_position, paddle_box|

      # center the box
      paddle_box.obj.x = paddle_position.x - (paddle_box.obj.w/2)
      paddle_box.obj.y = paddle_position.y - (paddle_box.obj.h/2)

      if future_ball.collide_with_rec? paddle_box.obj
        if future_ball_side.collide_with_rec? paddle_box.obj
          # if it is colliding from above/below then dont bounce back
          # and set horizontal speed to 0
          ball_velocity.y = 0
        else
          if paddle.side == 'right'
            unless ball_velocity.x < 0
              opposite = Cmp::Paddle.find { |pad| pad.side == 'left' }.entity
              opposite_position = opposite.component[Cmp::Position]
              opposite.add Cmp::EaseToward.new(start: opposite_position.y, finish: (60..(WindowHeight-60)).to_a.sample, time: 0)
              ball_velocity.x = -ball_velocity.x.abs
              $points += 1
            end
          else
            unless ball_velocity.x > 0
              opposite = Cmp::Paddle.find { |pad| pad.side == 'right' }.entity
              opposite_position = opposite.component[Cmp::Position]
              opposite.add Cmp::EaseToward.new(start: opposite_position.y, finish: (60..(WindowHeight-60)).to_a.sample, time: 0)
              ball_velocity.x = ball_velocity.x.abs
              $points += 1
            end
          end
        end
      end
      ball_position.x += ball_velocity.x
      ball_position.y += ball_velocity.y
    end
  end,

  Sys.new('CheckDeath') do
    # if ball outside of screen
    ball_position = Cmp::Ball.first.entity.component[Cmp::Position]
    ball_box = Cmp::Ball.first.entity.component[Cmp::Box]
    ball_box.obj.x = ball_position.x - (ball_box.obj.w/2)
    ball_box.obj.y = ball_position.y - (ball_box.obj.h/2)

    unless ball_box.obj.collide_with_rec? $world_rec
      Scn::Main.remove(Sys::Move)
      $dead = true
      if $points > $best_points
        $best_points = $points
      end
    end

  end,

  Sys.new('Render') do
    Ent.group(Cmp::Paddle, Cmp::Position, Cmp::Box, Cmp::Color) do |paddle, position, box, color|
      box.obj.x = position.x - (box.obj.w/2)
      box.obj.y = position.y - (box.obj.h/2)
      puts box.obj
      box.obj.draw(color: color.obj)
    end
    Ent.group(Cmp::Ball, Cmp::Position, Cmp::Box, Cmp::Color) do |paddle, position, box, color|
      box.obj.x = position.x - (box.obj.w/2)
      box.obj.y = position.y - (box.obj.h/2)
      box.obj.draw(color: color.obj)
    end
    "Points: #{$points}".draw(color: Rl::Color.dodger_blue, font_size: 48, x: 10, y: 10)
    if $dead
      "The Ball is Lost".draw(color: Rl::Color.fire_brick, font_size: 65, x: 130, y: 150)
      "Press R to try again".draw(color: Rl::Color.fire_brick, font_size: 30, x: 205, y: 270)
      "Best Score: #{$best_points}".draw(color: Rl::Color.fire_brick, font_size: 30, x: 205, y: 270 + 50)
    end
  end,

  Sys.new('IncrementFrame') do
    $frames += 1
  end,
)

Scn::Main.remove(Sys::Move, Sys::Gravity) # dont begin moving at the start

# define order systems should be executed in
Order.sort(
  Sys::Input,
  Sys::Gravity,
  Sys::EaseToward,
  Sys::Move,
  Sys::CheckDeath,
  Sys::Render,
  Sys::IncrementFrame
)

Rl.target_fps = 60
Rl.while_window_open do
  Rl.draw(clear_color: Rl::Color.black) do
    Scn::Main.call # execute the main scene once per frame
  end
end

