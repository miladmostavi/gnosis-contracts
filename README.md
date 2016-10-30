# Gnosis Smart Contracts

Use `vagrant up` then

### To run all tests:
`cd /vagrant/`
`python -m unittest discover contracts`

### Run one test:
`cd /vagrant/`
`python -m unittest contracts.tests.test_name`

### To deploy all contracts:
`cd /vagrant/contracts/`
`python deploy.py -f deploy/all.json`

### To deploy all contracts required for the token launch:
`python deploy.py -f deploy/tokenlaunch.json`
