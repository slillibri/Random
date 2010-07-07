#!/usr/bin/env ruby

## Script for automatically creating collages, adapted for my own uses from the script at
## http://weare.buildingsky.net/2006/10/18/render-greatlooking-collages-with-ruby-and-rmagick

require 'find'
require 'rubygems'
require 'getoptlong'
require 'RMagick'
require 'uuid'
include Magick

class Dimensions
  attr_accessor :width, :height
  def initialize(width, height)
    self.width = width
    self.height = height
  end
end

def backandforth(degree)
  polarity = rand(2) * -1
  return rand(degree) * polarity if polarity < 0
  return rand(degree)
end

def create_slide(image, dimensions)
  ## determine the rotations
  slide_rotate = backandforth(15)
  photo = Image.read(image).first

  ## Composite the photo on a transparent background or we get a white background when it gets rotated
  background = Image.new(photo.columns, photo.rows) {self.background_color = 'transparent'}
  background.composite!(photo, 0, 0, OverCompositeOp)
  background.rotate!(slide_rotate)

  bounding_height = (dimensions.height * 0.35)
  bounding_width = (dimensions.width * 0.33)
  background.resize_to_fit!(bounding_width, bounding_height)

  ## Add the background shadow.
  workspace = Image.new(background.columns+5, background.rows+5) {self.background_color = 'transparent'}
  shadow = background.shadow(0, 0, 2.0, '30%')
  workspace.composite!(shadow, 3, 3, OverCompositeOp)
  workspace.composite!(background, NorthWestGravity, OverCompositeOp)
  
  return workspace
end

### MAIN ###

opts = GetoptLong.new(
    ['--source', '-s', GetoptLong::REQUIRED_ARGUMENT],
    ['--count', '-c', GetoptLong::REQUIRED_ARGUMENT],
    ['--basename', '-b', GetoptLong::REQUIRED_ARGUMENT])

basedir = ''
count = 1
basename = 'collage'
begin
  opts.each do |opt,arg|
    case opt
    when '--source'
      basedir = arg
    when '--count'
      count = arg.to_i
    when '--basename'
      basename = arg
    end    
  end
rescue
  opts.error_message()
  exit(1)
end

baseimages = Array.new
puts "Finding files"
Find.find(basedir) {|file|
  if file =~ /\.jpg$/
    baseimages.push(file)
  end
}

(1..count).each do |counter|
  ## Randomly choose 4 images.
  images = Array.new
  4.times do
    image_number = rand(baseimages.size)
    redo if images.include? baseimages[image_number]
    images.push baseimages[image_number]
  end

  photo = Image.read("#{images.shift}").first
  dimensions = Dimensions.new(photo.columns, photo.rows)

  template = Image.new(photo.columns + 20, photo.rows + 160)
  
  template.composite!(photo, 10, 10, OverCompositeOp)
  
  slides = Array.new
  current_position = 5
  images.each do |image|
    slide = create_slide(image, dimensions)
    template.composite!(slide, current_position, (template.rows - slide.rows) - rand(20), OverCompositeOp)
    current_position = current_position + slide.columns
  end
    
  puts "Writing #{basename}#{counter}.png"
  
  template.write("#{basename}#{counter}.png") {self.quality = 75}
end

__END__
Bounding box for slide is original_height * 0.20 x original_width * 0.33
Bounding_width = (original_width * 0.33) - 40  (to account for border)
Bounding_height = (original_height * 0.20) - 40 
If width is the long side
  resize to bounding_width
otherwise
  calculate scale is (bounding_height / height) * 100
  resize to scale
end