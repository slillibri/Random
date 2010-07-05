#!/usr/bin/env ruby

## Script for automatically creating collages, adapted for my own uses from the script at
## http://weare.buildingsky.net/2006/10/18/render-greatlooking-collages-with-ruby-and-rmagick

require 'find'
require 'rubygems'
require 'getoptlong'
require 'RMagick'
include Magick

def backandforth(degree)
  polarity = rand(2) * -1
  return rand(degree) * polarity if polarity < 0
  return rand(degree)
end

def create_slide(image)
  ## read and resize the slide photo
  photo = Image.read(image).first
  photo.resize!(0.25)
  
  # create a grey scale gradient fill for our mask
  mask_fill = GradientFill.new(0, 0, 0, photo.rows, '#FFFFFF', '#F0F0F0')
  mask = Image.new(photo.columns, photo.rows, mask_fill)

  ## Construct the slide image, and resize for photo
  ## TODO construct a proper slide image
  slide = Image.new(photo.columns + 40, photo.rows + 40) { self.background_color = 'white' }
  slide_background = Image.new(slide.columns, slide.rows) { self.background_color = 'transparent' }
  #photo.crop_resized!(138,138)

  # apply alpha mask to slide
  photo.matte = true
  mask.matte = false
  photo.composite!(mask, 0, 0, CopyOpacityCompositeOp)
  
  # composite photo and slide on transparent background
  slide_background.composite!(slide, 0, 0, OverCompositeOp)
  slide_background.composite!(photo, 20, 20, OverCompositeOp)
  
  # rotate slide +/- 45 degrees
  rotation = backandforth(15)
  slide_background.rotate!(rotation)
  
  # create workspace to apply shadow
  workspace = Image.new(slide_background.columns+5, slide_background.rows+5) { self.background_color = 'transparent' }
  shadow = slide_background.shadow(0, 0, 2.0, '30%')
  workspace.composite!(shadow, 3, 3, OverCompositeOp)
  workspace.composite!(slide_background, NorthWestGravity, OverCompositeOp)
  
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
      count = arg
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
1.upto(count.to_i) {|counter|
  ## Randomly choose 4 images.
  images = Array.new
  (1..4).each do
    image_number = rand(baseimages.size)
    redo if images.include? baseimages[image_number]
    images.push baseimages[image_number]
  end
  
  photo = Image.read("#{images.shift}").first
  template = Image.new(photo.columns + 20, photo.rows + 160)
  
  template.composite!(photo, 10, 10, OverCompositeOp)
  
  slides = Array.new
  (images.size-1).downto(0) do |i|
    slides.push create_slide("#{images[i]}")
  end

  current_position = 0
  slides.each do |slide|
    template.composite!(slide, current_position, (template.rows - slide.rows) + rand(20), OverCompositeOp)
    current_position = current_position + slide.columns
  end
    
  puts "Writing #{basename}#{counter}.png"
  
  template.write("#{basename}#{counter}.png")
}
