// Mikrotik supout.rif decoder from https://github.com/farseeker/go-mikrotik-rif
//
// Based on unsup.pl by paul@unsup.sbrk.co.uk
// Golang version: (c) 2019 Mark Henderson
// Released under the MIT License
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

package main

import (
	"bufio"
	"bytes"
	"compress/zlib"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"strings"
)

func main() {
	if len(os.Args) != 2 {
		printHelp()
	}
	filename := os.Args[1]
	if filename == "" {
		printHelp()
	}

	file, err := os.Open(filename)
	if err != nil {
		fmt.Println("Error opening RIF file:", err)
		os.Exit(1)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var section strings.Builder
	for scanner.Scan() {
		line := scanner.Text()
		if line == "--BEGIN ROUTEROS SUPOUT SECTION" {
			section.Reset()
			continue
		}
		if line == "--END ROUTEROS SUPOUT SECTION" {
			err := mikrotikDecode(section.String())
			if err != nil {
				fmt.Println("Error decoding RIF section:", err)
			}
		}
		section.WriteString(line)
	}

	return
}

func printHelp() {
	fullPath := strings.Replace(os.Args[0], "\\", "/", -1) // Windows uses \ for dir separator, which doesn't work on path.Split
	_, exe := path.Split(fullPath)
	fmt.Printf("Usage: %s /path/to/supout.rif\n", exe)
	os.Exit(1)
}

func mikrotikDecode(section string) error {
	if len(section) == 0 {
		return fmt.Errorf("Empty section data")
	}

	const b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=" //Terminating "=" is so that index% 64 == 0 for pad char
	var out []byte
	for i := 0; i < len(section); i += 4 {
		packet := section[i : i+4]
		o := strings.Index(b64, string(packet[3]))%64<<18 |
			strings.Index(b64, string(packet[2]))%64<<12 |
			strings.Index(b64, string(packet[1]))%64<<6 |
			strings.Index(b64, string(packet[0]))%64

		out = append(out, byte(o%256), byte((o>>8)%256), byte((o>>16)%256))
	}

	sectionSplit := bytes.Index(out, []byte{0x0})
	sectionName := string(out[0:sectionSplit])
	sectionDataZ := out[sectionSplit+1:]

	zR, err := zlib.NewReader(bytes.NewReader(sectionDataZ))

	if err != nil {
		return err
	}
	defer zR.Close()

	fmt.Println("== SECTION", sectionName)
	sectionData, err := ioutil.ReadAll(zR)
	if err != nil {
		return err
	}
	fmt.Println(string(sectionData))
	fmt.Println()

	return nil
}
