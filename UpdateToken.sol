pragma solidity ^0.4.11;

    /// Name:       Update token
    /// Symbol:     UPT
    /// Website:    www.updatetoken.org
    /// Telegram:   https://t.me/updatetoken
    /// Twitter:    https://twitter.com/token_update
    /// Gitgub:     https://github.com/UpdateToken

library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        //require(c >= a); //added
        return c;
    }
}

contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnershipUpdateToken(address newAddress) onlyOwner {
        require(newAddress != address(0));
        owner = newAddress;
    }

}

contract Pausable is Ownable {
      event PausePublic(bool newState);
      event PauseOwnerAdmin(bool newState);
    
      bool public pausedPublic = true;
      bool public pausedOwnerAdmin = false;
    
      address public admin;
    
      modifier whenNotPaused() {
        if(pausedPublic) {
          if(!pausedOwnerAdmin) {
            require(msg.sender == admin || msg.sender == owner);
          } else {
            revert();
          }
        }
        _;
      }

      function pauseUpdateToken(bool newPausedPublic, bool newPausedOwnerAdmin) onlyOwner public {
        require(!(newPausedPublic == false && newPausedOwnerAdmin == true));
    
        pausedPublic = newPausedPublic;
        pausedOwnerAdmin = newPausedOwnerAdmin;
    
        PausePublic(newPausedPublic);
        PauseOwnerAdmin(newPausedOwnerAdmin);
      }
}

contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) constant returns (uint256);
    function transfer(address to, uint256 value) returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) returns (bool);
    function approve(address spender, uint256 value) returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract UpdateTokenStandard {
    uint256 public stakeStartTime;
    uint256 public stakeMinAge;
    uint256 public stakeMaxAge;
    function mint() returns (bool);
    function coinAge() constant returns (uint256);
    function annualInterest() constant returns (uint256);
    event Mint(address indexed _address, uint _reward);
}

    contract UpdateToken is ERC20,UpdateTokenStandard,Ownable {

    using SafeMath for uint256;

    string public symbol = "UPT";
    string public name = "Update Token";
    uint public decimals = 18;

    uint public chainStartTime; 
    uint public chainStartBlockNumber; 
    uint public stakeStartTime; 
    uint public stakeMinAge = 1 days; 
    uint public stakeMaxAge = 365 days;
    uint public maxMintProofOfStake = 5**17;

    uint public totalSupply;
    uint public maxTotalSupply;
    uint public totalInitialSupply;

    struct transferInStruct{
    uint128 amount;
    uint64 time;
    }

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    mapping(address => transferInStruct[]) transferIns;

    event Burn(address indexed burner, uint256 value);

    modifier antiShortAddressAttack(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    modifier enablePOS() {
        require(totalSupply < maxTotalSupply);
        _;
    }

    address public founder = 0x764377415c79aCcaC707BDB899C0d8c8d930a8ab;

    function UpdateToken() {
        maxTotalSupply = 150000000000000000000000000; 
        totalInitialSupply = 100000000000000000000000000;

        chainStartTime = now;
        chainStartBlockNumber = block.number;

        balances[founder] = totalInitialSupply;
        totalSupply = totalInitialSupply;
        
        Transfer(address(0), founder, totalInitialSupply); //moet dit nog?

    }

    function transfer(address _to, uint256 _value) antiShortAddressAttack(2 * 32) returns (bool) {
        if(msg.sender == _to) return mint();
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        if(transferIns[msg.sender].length > 0) delete transferIns[msg.sender];
        uint64 _now = uint64(now);
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),_now));
        transferIns[_to].push(transferInStruct(uint128(_value),_now));
        return true;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(address _from, address _to, uint256 _value) antiShortAddressAttack(3 * 32) returns (bool) {
        require(_to != address(0));

        var _allowance = allowed[_from][msg.sender];

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        if(transferIns[_from].length > 0) delete transferIns[_from];
        uint64 _now = uint64(now);
        transferIns[_from].push(transferInStruct(uint128(balances[_from]),_now));
        transferIns[_to].push(transferInStruct(uint128(_value),_now));
        return true;
    }

    function approve(address _spender, uint256 _value) returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function claimUpdateToken() enablePOS returns (bool) {
        if(balances[msg.sender] <= 0) return false;
        if(transferIns[msg.sender].length <= 0) return false;

        uint reward = getProofOfStakeRewardUpdateToken(msg.sender);
        if(reward <= 0) return false;

        totalSupply = totalSupply.add(reward);
        balances[msg.sender] = balances[msg.sender].add(reward);
        delete transferIns[msg.sender];
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),uint64(now)));

        Mint(msg.sender, reward);
        return true;
    }

    function getBlockNumber() returns (uint blockNumber) {
        blockNumber = block.number.sub(chainStartBlockNumber);
    }

    function updateTokenAge() constant returns (uint myCoinAge) {
        myCoinAge = getUpdateTokenAge(msg.sender,now);
    }

    function annualInterestUpdateToken() constant returns(uint interest) {
        uint _now = now;
        interest = maxMintProofOfStake;
        if((_now.sub(stakeStartTime)).div(1 years) == 0) {
            interest = (10 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(1 years) == 1){
            interest = (9 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(2 years) == 2){
            interest = (8 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(3 years) == 3){ //toegevoegd
            interest = (7 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(4 years) == 4){
            interest = (6 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(5 years) == 5){
            interest = (5 * maxMintProofOfStake).div(100);
        }
        
    }

    function getProofOfStakeRewardUpdateToken(address _address) internal returns (uint) {
        require( (now >= stakeStartTime) && (stakeStartTime > 0) );

        uint _now = now;
        uint _coinAge = getUpdateTokenAge(_address, _now);
        if(_coinAge <= 0) return 0;

        uint interest = maxMintProofOfStake;

        if((_now.sub(stakeStartTime)).div(1 years) == 0) {
            interest = (10 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(1 years) == 1){
            interest = (9 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(2 years) == 2){
            interest = (8 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(3 years) == 3){
            interest = (7 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(4 years) == 4){
            interest = (6 * maxMintProofOfStake).div(100);
        } else if((_now.sub(stakeStartTime)).div(5 years) == 5){
            interest = (5 * maxMintProofOfStake).div(100);
        }

        return (_coinAge * interest).div(365 * (10**decimals));
    }

    function getUpdateTokenAge(address _address, uint _now) internal returns (uint _coinAge) {
        if(transferIns[_address].length <= 0) return 0;

        for (uint i = 0; i < transferIns[_address].length; i++){
            if( _now < uint(transferIns[_address][i].time).add(stakeMinAge) ) continue;

            uint nCoinSeconds = _now.sub(uint(transferIns[_address][i].time));
            if( nCoinSeconds > stakeMaxAge ) nCoinSeconds = stakeMaxAge;

            _coinAge = _coinAge.add(uint(transferIns[_address][i].amount) * nCoinSeconds.div(1 days));
        }
    }

    function ownerSetStakeStartTime(uint timestamp) onlyOwner {
        require((stakeStartTime <= 0) && (timestamp >= chainStartTime));
        stakeStartTime = timestamp;
    }
    
    //OK Alleen nog niet van owner balance
    function burnUpdateToken(uint _value) onlyOwner {
        _value = _value * 1000000000000000000;
        require(_value > 0);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        delete transferIns[msg.sender];
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),uint64(now)));

        totalSupply = totalSupply.sub(_value);
        totalInitialSupply = totalInitialSupply.sub(_value);
        maxTotalSupply = maxTotalSupply.sub(_value*10);

        Burn(msg.sender, _value);
    }
    
    mapping (address => bool) public frozenAccount;
    event FrozenFunds(address target, bool frozen);

    /// [{
    /// "type":"function",
    /// "inputs": [{"name":"target","type":"address"},{"name":"freeze","type":"bool"}],
    /// "name":"lockUpdateTokenAccount",
    /// "outputs": []
    /// }]
    
    /// OK
    
    function lockUpdateTokenAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
    
    /// [{
    /// "type":"function",
    /// "inputs": [{"name":"to","type":"address"},{"name":"ammount","type":"uint256"}],
    /// "name":"airdropUpdateToken",
    /// "outputs": []
    /// }]
    
    // BUG

    function airdropUpdateToken(address[] to, uint256[] ammount)
    onlyOwner
    returns (uint256) {
        //ammount = ammount * 1000000000000000000;
        uint256 a = 0;
        while (a < to.length) {
           Transfer(msg.sender, to[a], ammount[a]);
           a += 1;
        }
        return(a);
    }
    
        /// [{
    /// "type":"function",
    /// "inputs": [{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],
    /// "name":"transferFromToUpdateToken",
    /// "outputs": []
    /// }]
    
    //BUG

    function transferFromToUpdateToken(address _from, address _to, uint256 _value) onlyOwner public returns (bool success) {
        _value = _value * 1000000000000000000;
        //require(_value <= allowance[_from][msg.sender]);
        //allowance[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }
    
    /// [{
    /// "type":"function",
    /// "inputs": [{"name":"_from","type":"address"},{"name":"_value","type":"uint256"}],
    /// "name":"burnUpdateTokenFrom",
    /// "outputs": []
    /// }]
    
    //BUG
    
    function burnUpdateTokenFrom(address _from, uint256 _value) public returns (bool success) {
        _value = _value * 1000000000000000000;
        require(balances[_from] >= _value);   
      //  require(_value <= allowance[_from][msg.sender]);    
        balances[_from] -= _value;                         
      //  allowance[_from][msg.sender] -= _value;            
        totalSupply -= _value;                              
        emit Burn(_from, _value);
        return true;
    }

}
