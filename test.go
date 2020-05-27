package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	config "github.com/ipfs/go-ipfs-config"
	files "github.com/ipfs/go-ipfs-files"
	libp2p "github.com/ipfs/go-ipfs/core/node/libp2p"
	icore "github.com/ipfs/interface-go-ipfs-core"
	icorepath "github.com/ipfs/interface-go-ipfs-core/path"
	peerstore "github.com/libp2p/go-libp2p-peerstore"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/ipfs/go-ipfs/core"
	"github.com/ipfs/go-ipfs/core/coreapi"
	"github.com/ipfs/go-ipfs/plugin/loader" // This package is needed so that all the preloaded plugins are loaded automatically
	"github.com/ipfs/go-ipfs/repo/fsrepo"
	"github.com/libp2p/go-libp2p-core/peer"

)


func setupPlugins(externalPluginsPath string) error{
    //Load any external plugins if available on externalPluginsPath
    plugins, err := loader.NewPluginLoader(filepath.Join(externalPluginsPath, "plugins"))
    if err != nil {
        return fmt.Errorf("error loading plugins: %s", err)
    }

    //Load preloaded and external plugins
    if err := plugins.Initialize(); err != nil{
        return fmt.Errorf("error initializing plugins: %s", err)
    }
    
    if err := plugins.Inject(); err != nil{
        return fmt.Errorf("error initializing plugins: %s", err)
    }

    return nil
}

func createNode(ctx context.Context, repoPath string) (icore.CoreAPI, error){
    //Open the repo
    repo, err := fsrepo.Open(repoPath)
    if err != nil {
        return nil, err
    }

    //Construct the node
    nodeOptions := &core.BuildCfg{
        Online: true,
		Routing: libp2p.DHTOption, // This option sets the node to be a full DHT node (both fetching and storing DHT Records)
		// Routing: libp2p.DHTClientOption, // This option sets the node to be a client DHT node (only fetching records)
		Repo: repo,
    }

    node, err := core.NewNode(ctx, nodeOptions)
    if err != nil {
        return nil, err
    }
    
    //Attach the Core API to the constructed node
    return coreapi.NewCoreAPI(node)
}

func spawnDefault(ctx context.Context) (icore.CoreAPI, error){
    defaultPath, err := config.PathRoot()

    fmt.Println("Default Path: ", defaultPath)

    if err != nil {
        return nil, err
    }

    if err := setupPlugins(defaultPath); err != nil {
        return nil, err
    }
       
	return createNode(ctx, defaultPath)
}

func getUnixfsNode(path string) (files.Node, error) {
	st, err := os.Stat(path)
	if err != nil {
		return nil, err
	}

	f, err := files.NewSerialFile(path, false, st)
	if err != nil {
		return nil, err
	}

	return f, nil
}

func getUnixfsFile(path string) (files.File, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	st, err := file.Stat()
	if err != nil {
		return nil, err
	}

	f, err := files.NewReaderPathFile(path, file, st)
	if err != nil {
		return nil, err
	}

	return f, nil
}

func connectToPeers(ctx context.Context, ipfs icore.CoreAPI, peers []string) error{
    var wg sync.WaitGroup
    peerInfos := make(map[peer.ID]*peerstore.PeerInfo, len(peers))//map[keyType]ValueType

    for _, addrStr := range peers {
        addr, err := ma.NewMultiaddr(addrStr)
        if err != nil {
            return err
        }
        pii, err := peerstore.InfoFromP2pAddr(addr)
        if err != nil {
            return err
        }
        pi, ok := peerInfos[pii.ID]
        if !ok{
            pi = &peerstore.PeerInfo{ID: pii.ID}
            peerInfos[pi.ID] = pi
        }
        pi.Addrs = append(pi.Addrs, pii.Addrs...)
    }

    wg.Add(len(peerInfos))
    for _, peerInfo := range peerInfos{
        go func(peerpeerInfo *peerstore.PeerInfo){
            defer wg.Done()
            err := ipfs.Swarm().Connect(ctx, *peerpeerInfo)
            if err != nil {
                log.Printf("failed to connect to %s: %s", peerpeerInfo.ID, err)
            }
        }(peerInfo)
    }
    wg.Wait()
    return nil
}

func main(){
    fmt.Println("-- Getting an IPFS node running -- ")
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Spawn a node using the default paht (~/.ipfs), assuming that a repo exists there already
    
    fmt.Println(" Spawing node on default repo")
    ipfs, err := spawnDefault(ctx)
    if err != nil {
        fmt.Println("No IPDS repo available on the default path")
    }

	/// --- Part II: Adding a file and a directory to IPFS

	fmt.Println("\n-- Adding and getting back files & directories --")

	inputBasePath := "./pippo/"
	inputPathFile := inputBasePath + "lol.txt"
	inputPathDirectory := inputBasePath + "test-dir"

    someFile, err := getUnixfsNode(inputPathFile)
    if err != nil{
        panic(fmt.Errorf("Could not get File: %s", err))
    }

    cidFile, err := ipfs.Unixfs().Add(ctx, someFile)
    if err != nil {
        panic(fmt.Errorf("Could not get File: %s", err))
    }

    fmt.Println("Added file to IPFS with CID %s\n", cidFile.String())

    someDirectory, err := getUnixfsNode(inputPathDirectory)
    if err != nil {
        panic(fmt.Errorf("Could not get File: %s", err))
    }

    cidDirectory, err := ipfs.Unixfs().Add(ctx, someDirectory)
    if err != nil{
        panic(fmt.Errorf("Could not add Directory: %s", err))
    }

    fmt.Println("Added directory to IPFS with CID %s\n", cidDirectory.String())

    //Ho qualche perplessità. Come faccio a farlo rimanere acceso?

	/// --- Part III: Getting the file and directory you added back
	outputBasePath := "./pippo/"
	outputPathFile := outputBasePath + strings.Split(cidFile.String(), "/")[2]
	outputPathDirectory := outputBasePath + strings.Split(cidDirectory.String(), "/")[2]

	rootNodeFile, err := ipfs.Unixfs().Get(ctx, cidFile)
	if err != nil {
		panic(fmt.Errorf("Could not get file with CID: %s", err))
	}

	err = files.WriteTo(rootNodeFile, outputPathFile)
	if err != nil {
		panic(fmt.Errorf("Could not write out the fetched CID: %s", err))
	}

	fmt.Printf("Got file back from IPFS (IPFS path: %s) and wrote it to %s\n", cidFile.String(), outputPathFile)

	rootNodeDirectory, err := ipfs.Unixfs().Get(ctx, cidDirectory)
	if err != nil {
		panic(fmt.Errorf("Could not get file with CID: %s", err))
	}

	err = files.WriteTo(rootNodeDirectory, outputPathDirectory)
	if err != nil {
		panic(fmt.Errorf("Could not write out the fetched CID: %s", err))
	}
	fmt.Printf("Got directory back from IPFS (IPFS path: %s) and wrote it to %s\n", cidDirectory.String(), outputPathDirectory)

	/// --- Part IV: Getting a file from the IPFS Network

	fmt.Println("\n-- Going to connect to a few nodes in the Network as bootstrappers --")
	bootstrapNodes := []string{
		// IPFS Bootstrapper nodes.
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb",
		"/dnsaddr/bootstrap.libp2p.io/p2p/QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt",

		// IPFS Cluster Pinning nodes
		"/ip4/138.201.67.219/tcp/4001/p2p/QmUd6zHcbkbcs7SMxwLs48qZVX3vpcM8errYS7xEczwRMA",
		"/ip4/138.201.67.219/udp/4001/quic/p2p/QmUd6zHcbkbcs7SMxwLs48qZVX3vpcM8errYS7xEczwRMA",
		"/ip4/138.201.67.220/tcp/4001/p2p/QmNSYxZAiJHeLdkBg38roksAR9So7Y5eojks1yjEcUtZ7i",
		"/ip4/138.201.67.220/udp/4001/quic/p2p/QmNSYxZAiJHeLdkBg38roksAR9So7Y5eojks1yjEcUtZ7i",
		"/ip4/138.201.68.74/tcp/4001/p2p/QmdnXwLrC8p1ueiq2Qya8joNvk3TVVDAut7PrikmZwubtR",
		"/ip4/138.201.68.74/udp/4001/quic/p2p/QmdnXwLrC8p1ueiq2Qya8joNvk3TVVDAut7PrikmZwubtR",
		"/ip4/94.130.135.167/tcp/4001/p2p/QmUEMvxS2e7iDrereVYc5SWPauXPyNwxcy9BXZrC1QTcHE",
		"/ip4/94.130.135.167/udp/4001/quic/p2p/QmUEMvxS2e7iDrereVYc5SWPauXPyNwxcy9BXZrC1QTcHE",
    }

	go connectToPeers(ctx, ipfs, bootstrapNodes)

	exampleCIDStr := "QmWHPa9Fda9qo6iZE4dj374fgNtLoW4EmriiCwrs9w7hSk"

	fmt.Printf("Fetching a file from the network with CID %s\n", exampleCIDStr)
	outputPath := outputBasePath + exampleCIDStr
	testCID := icorepath.New(exampleCIDStr)

	rootNode, err := ipfs.Unixfs().Get(ctx, testCID)
	if err != nil {
		panic(fmt.Errorf("Could not get file with CID: %s", err))
	}

	err = files.WriteTo(rootNode, outputPath)
	if err != nil {
		panic(fmt.Errorf("Could not write out the fetched CID: %s", err))
	}

	fmt.Printf("Wrote the file to %s\n", outputPath)

	fmt.Println("\nAll done! You just finalized your first tutorial on how to use go-ipfs as a library")

}
