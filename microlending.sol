// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPriceOracle {
    function getLatestPrice(address token) external view returns (uint256);
}

contract MicroLending {
    struct Loan {
        address borrower;
        address lender;
        uint256 amount;
        uint256 interest; // Interest in basis points (1% = 100)
        uint256 deadline; // Loan repayment deadline (timestamp)
        uint256 collateral; // Collateral amount in wei
        address collateralToken; // Token used as collateral (address for ERC-20 or 0x0 for native token)
        uint256 repaidAmount; // Amount already repaid
        bool active;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public loanCount;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public gracePeriod = 7 days; // Grace period after deadline
    uint256 public platformFeeBasisPoints = 50; // Platform fee (0.5%)

    IPriceOracle public priceOracle;
    address public owner;

    // Events
    event LoanRequested(uint256 loanId, address indexed borrower, uint256 amount, uint256 interest, uint256 collateral, address collateralToken, uint256 deadline);
    event LoanFunded(uint256 loanId, address indexed lender);
    event LoanRepaid(uint256 loanId, address indexed borrower, uint256 amountRepaid);
    event LoanLiquidated(uint256 loanId, address indexed lender);

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Not the borrower");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(msg.sender == loans[loanId].lender, "Not the lender");
        _;
    }

    modifier activeLoan(uint256 loanId) {
        require(loans[loanId].active, "Loan is not active");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _priceOracle) {
        priceOracle = IPriceOracle(_priceOracle);
        owner = msg.sender;
    }

    /// @notice Borrower requests a loan
    function requestLoan(uint256 amount, uint256 interest, uint256 duration, uint256 collateral, address collateralToken) external payable {
        require(amount > 0, "Loan amount must be greater than zero");
        require(interest > 0 && interest < BASIS_POINTS_DIVISOR, "Invalid interest rate");
        require(duration > 0, "Duration must be greater than zero");

        if (collateralToken == address(0)) {
            require(msg.value == collateral, "Collateral amount mismatch");
        } else {
            IERC20(collateralToken).transferFrom(msg.sender, address(this), collateral);
        }

        loans[loanCount] = Loan({
            borrower: msg.sender,
            lender: address(0),
            amount: amount,
            interest: interest,
            deadline: block.timestamp + duration,
            collateral: collateral,
            collateralToken: collateralToken,
            repaidAmount: 0,
            active: false
        });

        emit LoanRequested(loanCount, msg.sender, amount, interest, collateral, collateralToken, block.timestamp + duration);
        loanCount++;
    }

    /// @notice Lender funds a loan
    function fundLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(loan.borrower != address(0), "Invalid loan ID");
        require(!loan.active, "Loan already active");
        require(msg.value == loan.amount, "Incorrect loan amount");

        uint256 platformFee = (msg.value * platformFeeBasisPoints) / BASIS_POINTS_DIVISOR;
        payable(owner).transfer(platformFee);

        loan.lender = msg.sender;
        loan.active = true;

        payable(loan.borrower).transfer(msg.value - platformFee);

        emit LoanFunded(loanId, msg.sender);
    }

    /// @notice Borrower repays the loan (supports partial repayments)
    function repayLoan(uint256 loanId) external payable onlyBorrower(loanId) activeLoan(loanId) {
        Loan storage loan = loans[loanId];
        require(block.timestamp <= loan.deadline + gracePeriod, "Loan repayment deadline has passed");

        uint256 totalRepayment = loan.amount + (loan.amount * loan.interest) / BASIS_POINTS_DIVISOR;
        uint256 remainingAmount = totalRepayment - loan.repaidAmount;

        require(msg.value <= remainingAmount, "Repayment exceeds remaining amount");

        loan.repaidAmount += msg.value;
        payable(loan.lender).transfer(msg.value);

        if (loan.repaidAmount >= totalRepayment) {
            loan.active = false;

            if (loan.collateralToken == address(0)) {
                payable(loan.borrower).transfer(loan.collateral);
            } else {
                IERC20(loan.collateralToken).transfer(loan.borrower, loan.collateral);
            }
        }

        emit LoanRepaid(loanId, msg.sender, msg.value);
    }

    /// @notice Lender liquidates loan after deadline + grace period
    function liquidateLoan(uint256 loanId) external onlyLender(loanId) activeLoan(loanId) {
        Loan storage loan = loans[loanId];
        require(block.timestamp > loan.deadline + gracePeriod, "Loan repayment grace period has not passed");

        loan.active = false;

        if (loan.collateralToken == address(0)) {
            payable(loan.lender).transfer(loan.collateral);
        } else {
            IERC20(loan.collateralToken).transfer(loan.lender, loan.collateral);
        }

        emit LoanLiquidated(loanId, msg.sender);
    }

    /// @notice Get details of a loan
    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interest,
        uint256 deadline,
        uint256 collateral,
        address collateralToken,
        uint256 repaidAmount,
        bool active
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interest,
            loan.deadline,
            loan.collateral,
            loan.collateralToken,
            loan.repaidAmount,
            loan.active
        );
    }

    /// @notice Update platform fee
    function setPlatformFee(uint256 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints < BASIS_POINTS_DIVISOR, "Invalid fee basis points");
        platformFeeBasisPoints = newFeeBasisPoints;
    }

    /// @notice Update grace period for loan repayments
    function setGracePeriod(uint256 newGracePeriod) external onlyOwner {
        gracePeriod = newGracePeriod;
    }
}
