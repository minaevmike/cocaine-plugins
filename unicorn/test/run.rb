require 'securerandom'
require 'cocaine'
require 'rspec'

Cocaine::LOG.level = Logger::ERROR
Celluloid.logger.level = Cocaine::LOG.level

## This one is defined as hash of category name in cocaine.
ZK_ERROR_CATEGORY = 2039545343
UNICORN_ERROR_CATEGORY = 200582143

## These are zookeeper error codes

ZBADARGUMENTS = -8 # Invalid arguments */
ZAPIERROR = -100
ZNONODE = -101 # Node does not exist */
ZBADVERSION = -103 # Version conflict */
ZNODEEXISTS = -110 # The node already exists */
ZNOTEMPTY = -111 # The node has children */

CHILD_NOT_ALLOWED = 1
INVALID_TYPE = 2
INVALID_VALUE = 3
COULD_NOT_CONNECT = 4
UNKNOWN_ERROR = 5
HANDLER_SCOPE_RELEASED = 6
INVALID_NODE_NAME = 7
INVALID_PATH = 8
VERSION_NOT_ALLOWED = 9
INVALID_CONNECTION_ENDPOINT = 10

def node_gen
  node = '/test/' + SecureRandom.hex
end

def node_val_gen
  values = [
      42,
      0.42,
      "test",
      "÷тест юникода÷",
      [1,"test"],
      {"testkey0" => [], "testkey1" => 42, "teskkey2" => {}},
      [[[[]]]],
      {"testkey" =>{"testkey" =>{"testkey" =>{"testkey" =>{"testkey" =>{}}}}}},
  ]
  values[rand() % values.length]
end

def create(name, val)
  unicorn = Cocaine::Service.new(:unicorn)
  tx, rx = unicorn.create(name, val)
	result = rx.recv()
	tx.close
	result
end

def get(name)
  unicorn = Cocaine::Service.new(:unicorn)
  tx, rx = unicorn.get(name)
	result = rx.recv()
	tx.close
	result
end

def del(name, version=0)
  unicorn = Cocaine::Service.new(:unicorn)
  tx, rx = unicorn.del(name, version)
  result = rx.recv()
  tx.close
  result
end

def put(name, value='test_value', version=0)
  unicorn = Cocaine::Service.new(:unicorn)
  tx, rx = unicorn.put(name, value, version)
  result = rx.recv()
  tx.close
  result
end

def ensure_del(name, version=0)
  result = del(name, version)
  expect(result[1][0]).to be true
end

def ensure_get(name, value, version=0)
  result = get(name)
  expect(result[1][0][0]).to eq value
  #version should be 0
  expect(result[1][0][1]).to eq version
end

def ensure_create(name, value)
  result = create(name, value)
  expect(result[1][0]).to be true
end

describe :Unicorn do

  it 'should return error for invalid path' do
		result = create("INVALID NODE", "VALUE")
		expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
		expect(result[1][0][1]).to eq ZBADARGUMENTS
	end

	it 'should perform simple "create"' do
    node = node_gen
    node_val = node_val_gen
    ensure_create(node, node_val)
    ensure_get(node, node_val)
    ensure_del(node)
  end

  it 'should create subnodes in "create"' do
    node_val = node_val_gen
    long_node = '/' + SecureRandom.hex + '/' + SecureRandom.hex + '/' + SecureRandom.hex + '/' + SecureRandom.hex
    ensure_create(long_node, node_val)
    ensure_get(long_node, node_val)
    ensure_del(long_node)
  end

  it 'should correctly handle "create" on existing node' do
    node = node_gen
    node_val = node_val_gen
    ensure_create(node, node_val)
    result = create(node, "Q")
    expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to eq ZNODEEXISTS
  end

  it 'should correctly handle "create" on existing node with children' do
    node = node_gen
    node_val = node_val_gen
    inner_node = node + '/' + SecureRandom.hex
    ensure_create(inner_node, node_val)
    result = create(node, node_val)
    expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to eq ZNODEEXISTS
    ensure_del(inner_node)
  end

  it 'should handle error on "create" for node which has parent with value' do
    node = node_gen
    node_val = node_val_gen
    inner_node = node + '/' + SecureRandom.hex
    ensure_create(node, node_val)
    puts 'created' + node
    result = create(inner_node, node_val)
    puts 'created ' + inner_node
    puts 'result : '
    print result
    expect(result[1][0][0]).to eq UNICORN_ERROR_CATEGORY
    expect(result[1][0][1]).to eq CHILD_NOT_ALLOWED
    sleep(30)
    ensure_del(inner_node)
    ensure_del(node)
  end

  it 'should perform "put" with correct input' do
    node = node_gen
    node_val = node_val_gen
    ensure_create(node, node_val)
    new_node_val = "QQ"
    result = put(node, new_node_val)
    expect(result[1][0]).to be true
    expect(result[1][1][0]).to eq new_node_val
    expect(result[1][1][1]).to eq 1
    ensure_get(node, new_node_val, 1)
    ensure_del(node, 1)
  end

  it 'should correctly handle "put" with incorrect version' do
    node = node_gen
    node_val = node_val_gen
    result = create(node, node_val)
    expect(result[1][0]).to be true

    node_new_val = node_val_gen
    result = put(node, node_new_val, 42)
    expect(result[1][0]).to be false
    expect(result[1][1][0]).to eq node_val
    expect(result[1][1][1]).to eq 0
    ensure_get(node, node_val, 0)
    ensure_del(node, 0)
  end

  it 'should correctly handle "put" on non-existing node' do
    node = node_gen
    node_val = node_val_gen
    result = put(node, node_val, -1)
    expect(result[1][0][0]).to eq UNICORN_ERROR_CATEGORY
    expect(result[1][0][1]).to eq VERSION_NOT_ALLOWED
    result = put(node, node_val, 0)
    expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to eq ZNONODE
  end

  it 'should correctly handle "put" error on node with children'

  it 'should handle "subscribe" for unexisting value' do
    node = node_gen
    node_val = node_val_gen
    unicorn = Cocaine::Service.new(:unicorn)
    timeout = 0.3
    tx, rx = unicorn.subscribe(node)
    result = rx.recv(timeout)
    expect(result[1][0][0]).to be nil
    expect(result[1][0][1]).to eq -1
    expect{
      rx.recv(timeout)
    }.to raise_error(Celluloid::TimeoutError)
    ensure_create(node, node_val)
    result = rx.recv(timeout)
    expect(result[1][0][0]).to eq node_val
    expect(result[1][0][1]).to eq 0

    expect{
      rx.recv(timeout)
    }.to raise_error(Celluloid::TimeoutError)
    ensure_del(node)
    result = rx.recv(timeout)
    expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to eq ZNONODE

    # After error subscription is cancelled
    ensure_create(node, node_val)
    expect{
      rx.recv(timeout)
    }.to raise_error(Celluloid::TimeoutError)

    ensure_del(node)
    tx.close
  end

  it 'should handle "subscribe" for existing value' do
    node = node_gen
    node_val = {'key' => 'value'}
    unicorn = Cocaine::Service.new(:unicorn)
    ensure_create(node, node_val)
    timeout = 0.3
    tx, rx = unicorn.subscribe(node)
    result = rx.recv(timeout)
    expect(result[1][0][0]).to eq node_val
    expect(result[1][0][1]).to eq 0
    ensure_del(node)
    result = rx.recv(timeout)
    expect(result[1][0][0]).to eq ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to eq ZNONODE
    tx.close
  end

  it 'should handle "del" error on unexisting path' do
    node = node_gen
    unicorn = Cocaine::Service.new(:unicorn)
    for i in [-1, 0, 1]
      tx, rx = unicorn.del(node, i)
      result = rx.recv()
      expect(result[1][0][0]).to be ZK_ERROR_CATEGORY
      expect(result[1][0][1]).to be ZNONODE
    end
  end

  it 'should handle "del" error on invalid version path'
  it 'should handle "del" correctly on valid path and version' do
    node = node_gen
    node_val = {'key' => 'value'}
    unicorn = Cocaine::Service.new(:unicorn)
    ensure_create(node, node_val)
    ensure_del(node)
    ensure_create(node, node_val)
    node_val = "TEST_VALUE"
    put(node, node_val, 0)
    node_val = "TEST_VALUE2"
    put(node, node_val, 1)
    result = del(node, 42)
    expect(result[1][0][0]).to be ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to be ZBADVERSION
    ensure_del(node, 2)
    result = del(node, 42)
    expect(result[1][0][0]).to be ZK_ERROR_CATEGORY
    expect(result[1][0][1]).to be ZNONODE
  end

  it 'should handle "increment" on new node' do
    node = node_gen
    unicorn = Cocaine::Service.new(:unicorn)
    tx, rx = unicorn.increment(node, 42)
    result = rx.recv()
    expect(result[1][0][0]).to eq 42
    expect(result[1][0][1]).to eq 0
    ensure_get(node, 42, 0)
    ensure_del(node)
    tx, rx = unicorn.increment(node, 42.5)
    result = rx.recv()
    expect(result[1][0][0]).to eq 42.5
    expect(result[1][0][1]).to eq 0
    ensure_get(node, 42.5, 0)
    ensure_del(node)
  end

  it 'should handle "increment" on integer node' do
    node = node_gen
    unicorn = Cocaine::Service.new(:unicorn)
    ensure_create(node, 42)
    tx, rx = unicorn.increment(node, 10)
    result = rx.recv()
    expect(result[1][0][0]).to eq 52
    expect(result[1][0][1]).to eq 1
    tx, rx = unicorn.increment(node, 0.1)
    result = rx.recv()
    expect(result[1][0][0]).to eq 52.1
    expect(result[1][0][1]).to eq 2
    ensure_get(node, 52.1, 2)
    ensure_del(node, 2)
  end

  it 'should handle "increment" on float node' do
    node = node_gen
    unicorn = Cocaine::Service.new(:unicorn)
    ensure_create(node, 42.1)
    tx, rx = unicorn.increment(node, 10)
    result = rx.recv()
    expect(result[1][0][0]).to eq 52.1
    expect(result[1][0][1]).to eq 1
    tx, rx = unicorn.increment(node, 0.1)
    result = rx.recv()
    expect(result[1][0][0]).to eq 52.2
    expect(result[1][0][1]).to eq 2
    ensure_get(node, 52.2, 2)
    ensure_del(node, 2)
  end

  it 'should handle "increment" errors' do
    node = node_gen
    unicorn = Cocaine::Service.new(:unicorn)
    tx, rx = unicorn.increment(node, 'Invalid value')
    result = rx.recv()
    expect(result[1][0][0]).to be UNICORN_ERROR_CATEGORY
    expect(result[1][0][1]).to be INVALID_TYPE

    ensure_create(node, "QQ")
    tx, rx = unicorn.increment(node, 1)
    result = rx.recv()
    expect(result[1][0][0]).to be UNICORN_ERROR_CATEGORY
    expect(result[1][0][1]).to be INVALID_TYPE
    tx, rx = unicorn.increment(node, 0.1)
    result = rx.recv()
    expect(result[1][0][0]).to be UNICORN_ERROR_CATEGORY
    expect(result[1][0][1]).to be INVALID_TYPE
    ensure_del(node, 0)
  end

  it 'should handle "children_subscribe" correctly' do

  end

end
