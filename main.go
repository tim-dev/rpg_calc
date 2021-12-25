package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gorilla/mux"
	heroku "github.com/jonahgeorge/force-ssl-heroku"
	"github.com/rs/cors"
)

var (
	BUILD_DIR string
	PORT      = "8300"
)

func init() {
	var err error

	BUILD_DIR, err = filepath.Abs("public")
	if err != nil {
		panic(err)
	}

	if port, ok := os.LookupEnv("PORT"); ok {
		PORT = port
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, BUILD_DIR+"/index.html")
}

func router() http.Handler {
	router := mux.NewRouter()
	router.HandleFunc("/", handleIndex).Methods("GET")
	router.PathPrefix("/public/").Handler(http.StripPrefix("/public/", http.FileServer(http.Dir(BUILD_DIR))))

	return router
}
func main() {
	c := cors.AllowAll()
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", PORT),
		Handler:      heroku.ForceSsl(c.Handler(router())),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 60 * time.Second,
	}
	log.Printf("Starting http server on port %s\n", PORT)
	log.Fatal(srv.ListenAndServe())
}
