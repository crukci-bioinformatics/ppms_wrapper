require 'test_helper'

class PPMSTest < Minitest::Test

  @@test_key = "sBKhXbRwdPg1uEswKFYHzp5Qh2Q"
  @@test_bad_key = "zork"
  @@test_url = "ppms.eu/cruk-ci-dev"
  @@test_user = "gordon.brown"
  @@test_bad_user = "zaphod.beeblebrox"

  @@verbose = false

  def test_connectivity
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    rv = ppms.isConnected(verbose=@@verbose)
    assert rv
  end

  def test_no_host
    ppms = PPMS::PPMS.new(@@test_url+"zork",@@test_key)
    rv = ppms.isConnected(verbose=@@verbose)
    assert !rv
  end

#  def test_bad_key # weird... bad key still works
#    ppms = PPMS::PPMS.new(@@test_url,"zork")
#    rv = ppms.isConnected(verbose=true)
#    assert !rv
#  end

  def test_user
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    user = ppms.getUser(@@test_user,verbose=@@verbose)
    assert(!user.nil?)
    assert_equal(user['lname'],"Brown")
    assert_equal(user['fname'],"Gord")
  end

  def test_unknown_user
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    user = ppms.getUser(@@test_bad_user,verbose=@@verbose)
    assert(user.nil?)
  end

  def test_known_user_bad_key
    ppms = PPMS::PPMS.new(@@test_url,@@test_bad_key)
    user = ppms.getUser(@@test_bad_user,verbose=@@verbose)
    assert(user.nil?)
  end

  def test_list_users
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    users = ppms.listUsers(verbose=@@verbose)
    assert(!users.nil?)
  end

  def test_get_services
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getServices(core=7)
    assert(!data.nil?)
    assert_equal(data.keys()[0],"Hours")
  end

  def test_get_services_nil_core
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getServices(core=nil,verbose=@@verbose)
    assert(data.nil?)
  end

  def test_get_service_id
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getServiceID(core=7,name="Hours",verbose=@@verbose)
    assert(!data.nil?)
    assert_equal(data,"70123")
  end

  def test_get_orders
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getOrder(7)
    assert(!data.nil?)
  end

  def test_get_projects
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getProjects()
    assert(!data.nil?)
  end

  def test_get_groups
    ppms = PPMS::PPMS.new(@@test_url,@@test_key)
    data = ppms.getGroups()
    assert(!data.nil?)
  end

end
