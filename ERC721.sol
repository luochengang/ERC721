// SPDX-License-Identifier: MIT
// ERC721 Contract

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./ownable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard
 */
contract ERC721 is IERC721, Ownable {

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _tokenToOwner;

    // Mapping owner address to token count
    mapping(address => uint256) private _ownerTokenCount;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _ownerTokenCount[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view onlyMinted(tokenId) override returns (address) {
        address owner = _tokenToOwner[tokenId];
        return owner;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public onlyMinted(tokenId) override {
        address owner = ownerOf(tokenId);
        // 不能授权给自己
        require(to != owner, "ERC721: approval to current owner");

        // 授权发起人要么是拥有者, 要么是已经被拥有者授权所有资产的人
        // 为什么不能是已经被拥有者授权当前tokenId的人?
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view onlyMinted(tokenId) override returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public onlyMinted(tokenId) override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function mint(address to, uint256 tokenId) public onlyOwner {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_minted(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _ownerTokenCount[to] += 1;
        _tokenToOwner[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must have minted.
     *
     * Emits a {Transfer} event.
     */
    function burn(uint256 tokenId) public onlyMinted(tokenId) onlyOwnerOf(tokenId) {
        address owner = ownerOf(tokenId);
        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _ownerTokenCount[owner] -= 1;
        delete _tokenToOwner[tokenId];
        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * @param from The current owner of the NFT
     * @param to The new owner
     * @param tokenId The NFT to transfer
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        // 被转移的NFT必须属于from
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _ownerTokenCount[from] -= 1;
        _ownerTokenCount[to] += 1;
        _tokenToOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(operator != address(0), "ERC721: address zero is not a valid operator");
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Returns whether `tokenId` has been minted.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _minted(uint256 tokenId) internal view returns (bool) {
        return _tokenToOwner[tokenId] != address(0);
    }
    
    modifier onlyMinted(uint256 tokenId) {
        require(_tokenToOwner[tokenId] != address(0), "ERC721: invalid token ID");
        _;
    }
    
    modifier onlyOwnerOf(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId));
        _;
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal  {}
}
