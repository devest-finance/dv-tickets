const DvTicketFactory = artifacts.require("DvTicketFactory");
const DvTicket = artifacts.require("DvTicket");
const ERC20Mock = artifacts.require("ERC20PresetFixedSupply"); // This is a mock ERC20 token for testing

contract("OrderBook", accounts => {
    let dvTicket;
    let token;

    before(async () => {
        const dvTicketFactory = await DvTicketFactory.deployed();

        token = await ERC20Mock.new("Test Token", "TKO", 10000, accounts[0]); // Give account[0] 10000 tokens for testing
        await token.transfer(accounts[1], 1000, {from: accounts[0]}); // Give account[1] 1000 tokens for testing

        dvTicket = await dvTicketFactory.issue(token.address, "https://something", "HNK Orijent", "SN", { from: accounts[0] });
        dvTicket = await DvTicket.at(dvTicket.logs[0].args[1]);
        await dvTicket.initialize(0, 100, 5, { from: accounts[0] });
    });

    it("purchase tickets", async () => {
        await token.approve(dvTicket.address, 1000, {from: accounts[1]});
        await dvTicket.purchase(5, {from: accounts[1]});

        const balance = await dvTicket.balanceOf(accounts[1]);
        assert.equal(balance.toNumber(), 1);

        const ownerOfNumber5 = await dvTicket.ownerOf(5);
        assert.equal(ownerOfNumber5, accounts[1]);
    });

    it("Ticket fee was collected and transferred to owner", async () => {
        // check balance on contract
        const balance = await token.balanceOf(accounts[0]);

        // withdraw
        await dvTicket.withdraw({from: accounts[0]});

        // check balance on owner
        const balanceAfterWithdraw = await token.balanceOf(accounts[0]);
        assert.equal(balanceAfterWithdraw.toNumber(), balance.toNumber() + 5);
    });

});
