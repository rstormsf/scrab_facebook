require 'net/http'
require 'net/http/post/multipart'


module Antigate

  def self.send_captcha( key, captcha_file )
    uri = URI.parse( 'http://anti-captcha.com/in.php' )
    file = File.new( captcha_file, 'rb' )
    req = Net::HTTP::Post::Multipart.new( uri.path,
                                          :method => 'post',
                                          :key => key,
                                          :file => UploadIO.new( file, 'image/jpeg', 'image.jpg' ),
                                          :numeric => 1 )
    http = Net::HTTP.new( uri.host, uri.port )
    begin
      resp = http.request( req )
    rescue => err
      puts err
      return nil
    end#begin

    id = resp.body
    return id[ 3..id.size ]
  end#def
  def self.get_captcha_text( key, id )
  data = { :key => key,
           :action => 'get',
           :id => id,
           :min_len => 5,
           :max_len => 5 }
  uri = URI.parse('http://anti-captcha.com/res.php' )
  req = Net::HTTP::Post.new( uri.path )
  http = Net::HTTP.new( uri.host, uri.port )
  req.set_form_data( data )

  begin
    resp = http.request(req)
  rescue => err
    puts err
    return nil
  end

  text = resp.body
  if text != "CAPCHA_NOT_READY"
    return text[ 3..text.size ]
  end#if
  return nil
  end#def


  def self.report_bad( key, id )
    data = { :key => key,
             :action => 'reportbad',
             :id => id }
    uri = URI.parse('http://anti-captcha.com/res.php' )
    req = Net::HTTP::Post.new( uri.path )
    http = Net::HTTP.new( uri.host, uri.port )
    req.set_form_data( data )

    begin
      resp = http.request(req)
    rescue => err
      puts err
    end
  end#def
end#module

#
# key = 'KEY'
#
# captcha = 'image/c.jpg'
# recognition_time = 10
#
# #recognize capcha
# id = send_captcha( key, captcha )
# sleep( recognition_time )
# code = nil
# while code == nil do
#   code = get_captcha_text( key, id )
#   sleep 1
# end#while
# puts 'captcha: ' + code