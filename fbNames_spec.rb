require 'rspec'
require "selenium-webdriver"
require 'mongo'
require 'mechanize'
require File.expand_path(File.dirname(__FILE__) + '/antigate.rb')
include Antigate
require 'symmetric-encryption'
SymmetricEncryption.load!('config/symmetric-encryption.yml', 'production')


include Mongo

describe 'Facebook' do
  before(:all) do

    client = MongoClient.new("ds000000.mongolab.com", 49162)
    @db = client.db('dbname')
    auth = @db.authenticate('admin', 'PASSWORD')
    @coll = @db.collection("users")
    # @coll.create_index("fb_id")
    bulk = @coll.initialize_unordered_bulk_op

    @db.profiling_level = :all

    @driver = Selenium::WebDriver.for :firefox
    login
  end

  after(:all) do
    @db.profiling_level = :off

    @driver.quit
  end

  it 'should grab fb_id', :fb_id => true do
    @driver.navigate.to "https://www.facebook.com/directory/places/"

    @driver.find_element(:css, 'input#q_dashboard').clear
    @driver.find_element(:css, 'input#q_dashboard').send_keys("Los Angeles")
    @driver.find_element(:css, '#search_form_id > a').click
    @driver.find_elements(:css => '.mbm.detailedsearch_result')[0].find_element(:css => 'a').click
    sleep 5
    @driver.find_element(:partial_link_text => 'people').click

    sleep 5

    start =0
    ids = []
    begging_time = Time.now
    2.times { |time|
      jsonp = @driver.find_element(:css => '._akp[id^="u_jsonp_"]')
      elements = @driver.find_elements(:css => '[data-bt*="rank"]')
      start.upto(elements.size - 1) { |i|
        ids.push(JSON.parse(elements[i].attribute('data-bt'))['id'])
      }
      start = elements.size
      @driver.action.move_to(jsonp).perform
      sleep 2
      # puts "not unique #{ids.size}"
      ids = ids.uniq
      puts "N time is #{time} and collected ids + #{ids.size}"
      min = (Time.now - begging_time)/60
      # if (min > 5)
      #   sleep(30.seconds)
      # end

    }
    ids = ids.uniq
    ids.each {|id|
      @coll.insert({ :fb_id => id})
    }
    puts @driver.title
  end

  it 'should update ids with names and last names', :fb_names => true do
    @coll.find().to_a.each_with_index do |row, index|
      puts row['fb_id']
      recordId = row['fb_id']
      if recordId.nil? or row.keys.include? 'full_name'
        next
      end
      sleep 10
      @driver.navigate.to "https://www.facebook.com/#{recordId}"
      fullname = @driver.find_element(:css => "a[href= '#{@driver.current_url}' ]").text
      fullname = fullname.tr("()", '')
      firstName = fullname.split.first
      lastName = fullname.split[1]
      if fullname.split.size > 2
        lastName = fullname.split[2]
      end
      @coll.update({:fb_id => recordId},
                   { "$set" =>
                         {
                             :full_name => fullname,
                             :first_name => firstName,
                             :last_name => lastName
                         }
                   })
      puts recordId
      puts index
    end

  end

  it 'creates Gmail account', :gmail => true do
    @driver.execute_script('document.getElementsByTagName("html")[0].removeAttribute("webdriver")')
    @driver.navigate.to "https://www.gmail.com"
    @driver.find_element(:css => "#link-signup").click
    genders = {
        "female" => "e",
        "male" => "f"
    }
    code = solve_captcha

    password = (0...10).map { ('a'..'z').to_a[rand(26)] }.join
    puts "Password " + password
    year = rand(1970..1993)
    month = rand(1..12)
    day = rand(1..28)
    gender = Hash[*genders.to_a.sample]
    user = @coll.find({:gmail_reg => {"$ne" => false}}, {:limit => 1}).to_a.first
    gmail_address = user['last_name'] + user['first_name'] + rand(100..999).to_s
    puts gmail_address

    @driver.find_element(:css => "#FirstName").send_keys(user['first_name'])
    @driver.find_element(:css => "#LastName").send_keys(user['last_name'])
    @driver.find_element(:css => "#GmailAddress").send_keys(gmail_address)
    @driver.find_element(:css => "#Passwd").send_keys(password)
    @driver.find_element(:css => "#PasswdAgain").send_keys(password)
    @driver.find_element(:css => "#BirthMonth div:nth-child(1)").click
    sleep 5
    @driver.find_element(:id => ":#{month.to_s(16)}").click
    @driver.find_element(:id => "BirthDay").send_keys(day)
    @driver.find_element(:id => "BirthYear").send_keys(year)
    @driver.find_element(:css => "#Gender div:nth-child(1)").click
    sleep 5
    @driver.find_element(:id => ":#{gender.values[0]}").click
    @driver.find_element(:id => "recaptcha_response_field").send_keys(code)
    @driver.find_element(:id => "TermsOfService").click

    @driver.find_element(:id => "submitbutton").click
    # if is_displayed?() !@driver.find_element(:id => "EmailAddressExistsError").css_value("display") == "none" or !@driver.find_element(:id => "errormsg_0_GmailAddress").text.empty?
    #   @driver.find_element(:id => "username-suggestions").find_elements(:css => "a").sample.click
    # end
    #or check for URL
    @coll.update({:fb_id => user['fb_id']}, {
                                "$set" =>
                                    {
                                      :password => password,
                                      :year => year,
                                      :month => month,
                                      :day => day,
                                      :gender => gender.keys[0],
                                      :gmail_address => gmail_address,
                                      :gmail_reg => true
                                    }
                            })


    # @driver.find_element(:css => "#gmail-create-accoun t").click
  end


end


def login
  @driver.navigate.to "https://www.facebook.com/"
  @driver.find_element(:id => "email").send_keys("user@email.com")
  @driver.find_element(:id => "pass").send_keys('password')
  @driver.find_element(:css => "#loginbutton > input").click
end

def solve_captcha
  link = @driver.find_element(:id => "recaptcha_challenge_image").attribute("src")
  agent = Mechanize.new
  file = agent.get(link).save "image/c.jpg"

  key = 'KEY'
  # captcha = 'image/c.jpg'
  recognition_time = 10
  #
  # #recognize capcha
  id = Antigate.send_captcha( key, file )
  sleep( recognition_time )
  code = nil
  while code == nil do
    code = Antigate.get_captcha_text( key, id )
    sleep 1
  end#while
  puts 'captcha: ' + code
  return code
end

def is_displayed? (element)
  rescue_exceptions {element.displayed?}
end

def rescue_exceptions
  begin
    yield
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end
end