pragma solidity ^0.4.0;

// This is a Solidity version of Chris Calderon's implementation in Serpent, which is part of the Augur project.
// Original code: https://github.com/AugurProject/augur-core/blob/develop/src/data_api/fxpFunctions.se

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// License details at: <http://www.gnu.org/licenses/>.

/// @title Math library - Allows logarithmic and exponential functions.
/// @author Michael Lu - <michael.lu@consensys.net>
/// @author Stefan George - <stefan.george@consensys.net>
library MathLibrary {

    /*
     *  We set 1 as 2**64. 4 would be represented as 4*2**64.
     *  0.5 would be represented 2**63.
     *  To save space and allow for more in-depth manipulation,
     *  we have changed 1 :: 2**64 :: 16 ** 16 :: 0x10000000000000000
     */

    /*
     *  Constants
     */
    // This is equal to 1 in our calculations
    uint constant ONE = 0x10000000000000000;

    /*
     *  Read functions
     */
    /// @dev Returns natural exponential function value of given x.
    /// @param x X.
    /// @return exp Returns exponential value.
    function eExp(uint x)
        constant
        returns (uint exp)
    {
        /* This is equivalent to ln(2) */
        uint ln2 = 0xb17217f7d1cf79ac;
        uint y = x * ONE / ln2;
        uint shift = 2**(y / ONE);
        uint z = y % ONE;
        uint zpow = z;
        uint result = ONE;
        result += 0xb172182739bc0e46 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x3d7f78a624cfb9b5 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0xe359bcfeb6e4531 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x27601df2fc048dc * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x5808a728816ee8 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x95dedef350bc9 * zpow / ONE;
        result += 0x16aee6e8ef;
        exp = shift * result;
    }

    /// @dev Returns natural logarithm value of given x.
    /// @param x X.
    /// @return log Returns logarithmic value.
    function ln(uint x)
        constant
        returns (uint log)
    {
        uint log2e = 0x171547652b82fe177;
        // binary search for floor(log2(x))
        uint ilog2 = floorLog2(x);
        // lagrange interpolation for log2
        uint z = x / (2**ilog2);
        uint zpow = ONE;
        uint const = ONE * 10;
        uint result = const;
        result -= 0x443b9c5adb08cc45f * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0xf0a52590f17c71a3f * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x2478f22e787502b023 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x48c6de1480526b8d4c * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x70c18cae824656408c * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x883c81ec0ce7abebb2 * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x81814da94fe52ca9f5 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x616361924625d1acf5 * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x39f9a16fb9292a608d * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x1b3049a5740b21d65f * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x9ee1408bd5ad96f3e * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x2c465c91703b7a7f4 * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x918d2d5f045a4d63 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x14ca095145f44f78 * zpow / ONE;
        zpow = zpow * z / ONE;
        result -= 0x1d806fc412c1b99 * zpow / ONE;
        zpow = zpow * z / ONE;
        result += 0x13950b4e1e89cc * zpow / ONE;
        log = ((ilog2 * ONE + result - const) * ONE / log2e);
    }

    function floorLog2(uint x)
        constant
        private
        returns (uint lo)
    {
        lo = 0;
        uint y = x / ONE;
        uint hi = 191;
        uint mid = (hi + lo) / 2;
        while ((lo + 1) != hi) {
            if (y < 2**mid){
                hi = mid;
            }
            else {
                lo = mid;
            }
            mid = (hi + lo) / 2;
        }
    }
}
