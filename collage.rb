#!/usr/bin/env ruby

## Script for automatically creating collages, adapted for my own uses from the script at
## http://weare.buildingsky.net/2006/10/18/render-greatlooking-collages-with-ruby-and-rmagick

require 'find'
require 'rubygems'
require 'getoptlong'
require 'RMagick'
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
  ## read and resize the slide photo
  ## TODO photo should be scaled based on the original photo size
  photo = Image.read(image).first
  # photo.resize!(0.20)
  slide_rotate = backandforth(15)
  photo = scale_slide(image, dimensions, slide_rotate)

  ## Construct the slide image, and resize for photo
  ## TODO construct a proper slide image
  slide = Image.new(photo.columns + 40, photo.rows + 40) { self.background_color = 'white' }
  slide_background = Image.new(slide.columns, slide.rows) { self.background_color = 'transparent' }
  
  # composite photo and slide on transparent background
  slide_background.composite!(slide, 0, 0, OverCompositeOp)
  slide_background.composite!(photo, 20, 20, OverCompositeOp)
  
  # rotate slide +/- 45 degrees
  slide_background.rotate!(slide_rotate)
  
  # create workspace to apply shadow
  workspace = Image.new(slide_background.columns+5, slide_background.rows+5) { self.background_color = 'transparent' }
  shadow = slide_background.shadow(0, 0, 2.0, '30%')
  workspace.composite!(shadow, 3, 3, OverCompositeOp)
  workspace.composite!(slide_background, NorthWestGravity, OverCompositeOp)
  
  # workspace = scale_slide(workspace, dimensions)
  return workspace
end

def scale_slide(image, dimensions, slide_rotate)
  puts slide_rotate
  photo = Image.read(image).first
  photo2 = photo.rotate(slide_rotate)
  bounding_height = (dimensions.height * 0.30) - 40
  bounding_width = (dimensions.width * 0.33) - 40
  scale_width = photo2.columns * 0.33
  scale_height = photo2.rows * 0.30
  
  puts "photo #{photo2.rows}x#{photo2.columns}"
  puts "bounding #{bounding_height}x#{bounding_width}"
  puts "scale #{scale_height}x#{scale_width}"
  if photo2.columns > photo2.rows
    puts "image is wider, scaling to #{bounding_width}"
    ## 
    photo.resize_to_fill!(bounding_width)
  else
    scale_per = (bounding_height / photo2.rows)
    puts "image is taller, scaling to #{scale_per}%"
    photo.scale!(scale_per)
  end
  puts "#{photo.rows}x#{photo.columns}"
  return photo
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

puts "count #{count}"
puts "Images #{baseimages.size}"
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
  puts "dimensions #{dimensions.height}x#{dimensions.width}"
  template = Image.new(photo.columns + 20, photo.rows + 160)
  
  template.composite!(photo, 10, 10, OverCompositeOp)
  
  slides = Array.new
  current_position = 10
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