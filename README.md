[![CI status](https://github.com/BittyIO/StERC721/actions/workflows/test.yml/badge.svg)](https://github.com/BittyIO/StERC721/actions/workflows/test.yml)[![codecov](https://codecov.io/github/BittyIO/StERC721/graph/badge.svg?token=CSDZ9R6Z6U)](https://codecov.io/github/BittyIO/StERC721)

## StERC721

StERC721 is a secure staking protocol for ERC721 assets, with the following core functionalities:

1. Permissionless minting: Enables users to stake underlying ERC721 assets, thereby obtaining StERC721 credentials fully compliant with the EIP-721 standard.
   
2. Individualized vault architecture: Each user is allocated a dedicated vault, ensuring isolated custody of ERC721 assets.

3. Permissionless airdrop claiming mechanism: Supports trustless, permissionless claiming of airdrops.

4. Permissionless credential burning: Facilitates permissionless burning of StERC721 credentials to retrieve the corresponding underlying ERC721 assets.

5. Support for delegate.cash v2 configuration.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```