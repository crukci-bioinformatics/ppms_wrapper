require 'test_helper'

class PPMSTest < Minitest::Test

  @@test_key = "2TSryp1TB5j2LLShHsn5pGJ5Q2o92hy"
  @@test_bad_key = "zork"
  @@test_url = "ppms.eu/cruk-ci-dev"
  @@test_user = "gb455"
  @@test_bad_user = "zaphod.beeblebrox"

  @@verbose = false

  def test_connectivity
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    rv = ppms.isConnected(verbose=@@verbose)
    assert rv
  end

  def test_no_host
    ppms = PPMS::PPMS.new(host: @@test_url+"zork",key: @@test_key)
    rv = ppms.isConnected(verbose=@@verbose)
    assert !rv
  end

#  def test_bad_key # weird... bad key still works
#    ppms = PPMS::PPMS.new(host: @@test_url,"zork")
#    rv = ppms.isConnected(verbose=true)
#    assert !rv
#  end

  def test_user
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    user = ppms.getUser(@@test_user,verbose=@@verbose)
    assert(!user.nil?)
    assert_equal(user['lname'],"Brown")
    assert_equal(user['fname'],"Gordon")
  end

  def test_unknown_user
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    user = ppms.getUser(@@test_bad_user,verbose=@@verbose)
    assert(user.nil?)
  end

  def test_known_user_bad_key
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_bad_key)
    user = ppms.getUser(@@test_bad_user,verbose=@@verbose)
    assert(user.nil?)
  end

  def test_list_users
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    users = ppms.listUsers(verbose=@@verbose)
    assert(!users.nil?)
  end

  def test_get_services
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getServices(core: 7)
    assert(!data.nil?)
    assert_equal(data.keys()[0],"Hours")
  end

  def test_get_services_nil_core
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getServices(core: nil,verbose: @@verbose)
    assert(data.nil?)
  end

  def test_get_service_id
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getServiceID(core: 7,name: "Hours",verbose: @@verbose)
    assert(!data.nil?)
    assert_equal(data,"70112")
  end

  def test_get_orders
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getOrders(verbose=@@verbose)
    assert(!data.nil?)
    assert(data.include?('800'))
  end

  def test_get_order
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getOrder('800',verbose=@@verbose)
    assert(!data.nil?)
    order = data['800']
    assert(!order.nil?)
    assert_equal('Caldas Group', order['Group'])
  end

  def test_get_projects
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getProjects(verbose=@@verbose)
    assert(!data.nil?)
    plist = data.select{|p| p['Bcode'] == 'SWAG/001'}
    assert_equal(1, plist.length)
  end

  def test_get_accounts
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getAccounts()
    assert(!data.nil?)
    alist = data.select{|p| p['bcode'] == 'SWAG/002'}
    assert_equal(1, alist.length)
    account = alist[0]
    assert_equal('Compliance and Biobanking', account['descriptionShort'])
  end

  def test_get_groups
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    data = ppms.getGroups()
    assert(!data.nil?)
    assert(data.include?('Bioinformatics'))
  end

  def test_get_group
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    group = Project.create(name: 'Odom',is_public: false)
    printf("b\n")
    data = ppms.getGroup(group)
    printf('c')
    assert(!data.nil?)
    printf('d')
    assert(data.include?('unitlogin'))
    printf('e')
    assert(data['unitname'] == 'Odom Group')
    printf('f')
  end
  
  def test_load_prices
    ppms = PPMS::PPMS.new(host: @@test_url,key: @@test_key)
    prices = ppms.loadPrices(@@verbose)
    puts(prices)
    plist = prices.select{|p| p['service'] == '70112' && p['affiliation'] == 8}
    assert_equal(1, plist.length)
    price = plist[0]
    assert_equal(52.75, price['price'])
  end
end
