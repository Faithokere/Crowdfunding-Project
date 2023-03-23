//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;
import "class-stuff/crowdfund.sol";
//create an event named launch which comprises of id, creator, goal, startAt, endAt.
contract tech4dev{
    event Launch(
        //id of campaign
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(
        uint id
    );
    //allows people to donate
    event Pledge(
        //id of campaign pledger wants to contribute to
        uint indexed id,
        address indexed caller,
        uint amount
    );

    event Unpledge(
        uint indexed id,
        address indexed caller,
        uint amount
    );
    event Claim(
        uint indexed id
    );
    event Refund(
        uint id,
        address indexed caller,
        uint amount
    );

    struct Campaign{
        //creator of struct
        address creator;
        //Amount of token to raise
        uint goal;
        //Total amount pledged​
        uint pledged;
        //Timestamp of start of campaign​
        uint startAt;
        //Timestamp of end of campaign​
        uint endAt;
        //True if goal was reached and creator has claimed the tokens. If goal isn't reached claimed will return false as the creator won't be able to claim the token
        bool claimed;
    }

    IERC20 public immutable token;//making reference to the erc20
    //to attach an id for each campaign
    uint public count;
    //uint is id of campaign and Campaign is the struct name
    mapping(uint => Campaign) public campaigns;
    //map the id of the campaign and the address of the person trying to contribute money and the amount the person wants to contribute
    mapping(uint => mapping(address => uint)) public pledgedAmount;
    constructor(address _token) {
        token = IERC20(_token);
    }

    //function to launch campaign
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        //block.timestamp is the time a contract was deployed on the blockchain
        require(_startAt >= block.timestamp, "startAt < now");
        require(_endAt >= _startAt, "endAt < startAt");
        require(_endAt <= block.timestamp + 90 days, "endAt > 90 days");

        //to capture id
        count += 1;
    
    //for different campaigns so they don't clash. We're inputing the data into the struct Campaign
    //mappingName[count] = structName(input for the elements in the struct)
    //pledge is 0 because we're just launching the contract, so nobody has pledged
    campaigns[count] = Campaign(msg.sender, _goal, 0, _startAt, _endAt, false);

    emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    //function to enable the creator of the campaign delete the campaign
    function cancel(uint _id) external {
        //to index the id in the mapping
        //name of struct, memory(because we're not tampering with the struct, if we are, it'll be storage) new variable = mapping name[id from frontend]
        Campaign memory campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "You're not the creator");
        //check if the campaign has started, because we can't delete a campaign that has started
        require(block.timestamp < campaign.startAt, "The campaign has started");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    //function to enable someone pledge a certain amount to the campaign
    function pledge(uint _id, uint _amount) external {
        //storage, because we're tampering with the money in the struct
        Campaign storage campaign = campaigns[_id];
        //you can't pledge to a campaign that has not started
        require(block.timestamp >= campaign.startAt, "Campaign has not started");
        //you can't pledge after the campaign has ended
        require(block.timestamp <= campaign.endAt, "Campaign has ended");
        //whatever amount is pledged is added to the campaign
        campaign.pledged += _amount;
        //add the pledged amount to the nested mapping pledgedAmount
        pledgedAmount[_id][msg.sender] += _amount;
        //transfer money from pledger's wallet to campaigner's wallet
        token.transferFrom(msg.sender, address(this), _amount);
        emit Pledge(_id, msg.sender, _amount);
    }

    //function to enable the pledger get his money back
    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "Campaign has ended");
        campaign.pledged -= _amount;
        //transfer money from campaigner's wallet back to pledgers's wallet
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);
        emit Unpledge(_id, msg.sender, _amount);
    }

    //function to enable the campaign creator to claim the tokens
    function claim(uint _id) external{
        Campaign storage campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "You're not the creator");
        //campaign should have ended for the creator to be able to claim the tokens
        require(block.timestamp > campaign.endAt, "Campaign has not ended");
        require(campaign.pledged >= campaign.goal, "Pledged amount is less than goal");
        require(!campaign.claimed, "Campaign has been claimed");
        //campaign has been claimed
        campaign.claimed = true;

        //transfer the token to the creator's wallet
        token.transfer(campaign.creator, campaign.pledged);
        emit Claim(_id); 
    }

    //called by the person that pledged and it's all the money that's refunded
    function refund(uint _id) external{
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "Campaign has not ended");
        require(campaign.pledged < campaign.goal, "Pledged amount is more than goal");

        //save the amount you pledged in a variable
        uint balance = pledgedAmount[_id][msg.sender];
        //collect all your money
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, balance);
        emit Refund(_id, msg.sender, balance);
    }

    function second() public view returns(uint){
        return block.timestamp;
    }
}

//to pledge an amount, go to the erc20 token and mint a token for the particular address you want to use to pledge
//approve crowdfunding contract to be able to spend from the account
