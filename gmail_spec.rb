require 'rspec'
require "selenium-webdriver"
require 'mongo'
require 'mechanize'
#require File.expand_path(File.dirname(__FILE__) + '/antigate.rb')
require 'fileutils'
require 'deathbycaptcha'
require 'symmetric-encryption'
SymmetricEncryption.load!('config/symmetric-encryption.yml', 'production')

include Mongo

describe 'gmail mobile'  do
  before(:all) do
    client = MongoClient.new("ds000000.mongolab.com", 49162)
    @db = client.db('dbname')
    auth = @db.authenticate('admin', 'password')
    @coll = @db.collection("users")
    # @coll.create_index("fb_id")
    bulk = @coll.initialize_unordered_bulk_op

    @db.profiling_level = :all

    mobile_emulation = { "deviceName" => "Google Nexus 5" }
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(
        "chromeOptions" => { "mobileEmulation" => mobile_emulation })
    @driver = Selenium::WebDriver.for :remote, url: 'http://localhost:4444/wd/hub', desired_capabilities: caps

  end

  after(:all) do
    @driver.quit
  end


  it 'creates Gmail account', :gmail => true do
    @driver.navigate.to "https://www.gmail.com/"
    @driver.execute_script('document.getElementsByTagName("html")[0].removeAttribute("webdriver")')
    @driver.navigate.to "https://www.gmail.com"
    @driver.find_element(:css => "#link-signup").click
    genders = {
        "FEMALE" => "e",
        "MALE" => "f"
    }
    # code = solve_captcha
    code = deathbyc
    password = (0...10).map { ('a'..'z').to_a[rand(26)] }.join
    puts "Password " + password
    year = rand(1970..1993)
    month = rand(1..12)
    day = rand(1..28)
    gender = Hash[*genders.to_a.sample]
    user = @coll.find({:gmail_reg => {"$ne" => false}}, {:limit => 1}).to_a.first
    puts user
    gmail_address = user['last_name'] + user['first_name'] + rand(100..999).to_s
    puts gmail_address

    @driver.find_element(:css => "#FirstName").send_keys(user['first_name'])
    @driver.find_element(:css => "#LastName").send_keys(user['last_name'])
    @driver.find_element(:css => "#GmailAddress").send_keys(gmail_address)
    @driver.find_element(:css => "#Passwd").send_keys(password)
    @driver.find_element(:css => "#PasswdAgain").send_keys(password)

    recaptcha = @driver.find_element(:css => "#recaptcha_response_field")
    @driver.action.move_to(recaptcha).perform

    birthmonth = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id => "BirthMonth"))
    birthmonth.select_by(:index, month)


    birthday = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id => "BirthDay"))
    birthday.select_by(:index, day)


    birthyear = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id => "BirthYear"))
    birthyear.select_by(:value, year.to_s)

    genderEl = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id => "Gender"))
    genderEl.select_by(:value, gender.keys.first.upcase)

    tos = @driver.find_element(:id => "TermsOfService")
    @driver.action.move_to(tos).perform
    recaptcha.send_keys(code)
    tos.click

    @driver.find_element(:id => "submitbutton").click
    # if is_displayed?() !@driver.find_element(:id => "EmailAddressExistsError").css_value("display") == "none" or !@driver.find_element(:id => "errormsg_0_GmailAddress").text.empty?
    #   @driver.find_element(:id => "username-suggestions").find_elements(:css => "a").sample.click
    # end
    #or check for URL
    @coll.update({:fb_id => user['fb_id']}, {
                                              "$set" =>
                                                  {
                                                      :password => SymmetricEncryption.encrypt(password),
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


# def solve_captcha
#   link = @driver.find_element(:id => "recaptcha_challenge_image").attribute("src")
#   agent = Mechanize.new
#   FileUtils.rm_rf("image/.", secure: false)
#   file = agent.get(link).save "image/c.jpg"
#
#   key = 'MYKEY'
#   # captcha = 'image/c.jpg'
#   recognition_time = 10
#   #
#   # #recognize capcha
#   id = Antigate.send_captcha( key, file )
#   sleep( recognition_time )
#   code = nil
#   while code == nil do
#     code = Antigate.get_captcha_text( key, id )
#     sleep 1
#   end#while
#   puts 'captcha: ' + code
#   return code
# end

def deathbyc
  code = nil
  link = @driver.find_element(:id => "recaptcha_challenge_image").attribute("src")
  client = DeathByCaptcha.new('username', 'password', :http)
  captcha = client.decode(url: link)
  while code == nil do
    code = captcha.text
    sleep 1
  end
  code
  # captcha.id          # Numeric ID of the captcha solved by DeathByCaptcha
  # captcha.is_correct  # true if the solution is correct
end