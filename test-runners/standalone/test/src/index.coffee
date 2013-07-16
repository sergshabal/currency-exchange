chai = require 'chai'
chai.should()
expect = chai.expect

ChildDaemon = require 'child-daemon'
supertest = require 'supertest'

Operation = require('currency-market').Operation
Delta = require('currency-market').Delta
Amount = require('currency-market').Amount

describe 'currency-exchange', ->
  it 'should start an end to end system', (done) ->
    this.timeout 5000
    request = supertest 'http://localhost:7000'
    childDaemon = new ChildDaemon 'node', [
      'lib/local/src/index.js'
      '--config'
      'test/support/config.json'
    ], new RegExp 'Currency Exchange started'
    childDaemon.start (error, matched) =>
      expect(error).to.not.be.ok
      request
      .get('/balances/Peter/EUR')
      .set('Accept', 'application/json')
      .expect(200)
      .expect('Content-Type', /json/)
      .end (error, response) =>
        expect(error).to.not.be.ok
        oldBalance = parseFloat response.body.funds
        request
        .post('/deposits/Peter/')
        .set('Accept', 'application/json')
        .send
          currency: 'EUR'
          amount: '50'
        .expect(200)
        .expect('Content-Type', /json/)
        .end (error, response) =>
          expect(error).to.not.be.ok
          operationResponse = response.body
          operation = new Operation
            exported: operationResponse.operation
          operation.account.should.equal 'Peter'
          operation.sequence.should.be.a 'number'
          deposit = operation.deposit
          deposit.currency.should.equal 'EUR'
          deposit.amount.compareTo(new Amount '50').should.equal 0
          delta = new Delta
            exported: operationResponse.delta
          delta.result.funds.compareTo(new Amount '50').should.equal 0
          setTimeout =>
            request
            .get('/balances/Peter/EUR')
            .set('Accept', 'application/json')
            .expect(200)
            .expect('Content-Type', /json/)
            .end (error, response) =>
              expect(error).to.not.be.ok
              newBalance = parseFloat response.body.funds
              newBalance.should.equal oldBalance + 50
              childDaemon.stop (error) =>
                expect(error).to.not.be.ok
                done()
          , 250
