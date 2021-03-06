(ns subinitd.mq
  (:require [langohr.core      :as rmq]
            [langohr.channel   :as lch]
            [langohr.queue     :as lq]
            [langohr.consumers :as lc]
            [langohr.basic     :as lb]
            [clojure.string    :as str]
            [taoensso.timbre :as timbre]
            [subinitd.handler :as handler]
            [clojurewerkz.serialism.core :as s])
  (:gen-class))

(timbre/refer-timbre)



(defn- cmd-reply [ch orig reply]
  (let [dst (str/replace (:src orig) #"recv" "send")
        msg (s/serialize {:user (:user orig) :msg reply} :json)]
    (info (format "---> Handler reply orig_msg=%s key=%s: %s" msg dst msg))
    (lb/publish ch "msg" dst msg :content-type "application/json")))

(defn cmd-message-handler [ch {:keys [content-type delivery-tag] :as meta} ^bytes payload]
  (info (format "<--- Received message: %s, content type: %s"
          (String. payload "UTF-8") content-type))

  (when (= content-type "application/json")
    (try
      (let [msg (s/deserialize payload :json)]
        (cmd-reply ch msg (handler/handler msg)))
      (catch com.fasterxml.jackson.core.JsonParseException e
        (error "[HANDLER] json decode failed :("))))
  (lb/ack ch delivery-tag))

(defn cmd-consume [chan]
  (let [keys  ["telinit" "runlevel" "inspect"]
        ex    "cmd"
        qname (:queue (lq/declare chan))]

    (doseq [k keys]
      (lq/bind chan qname ex :routing-key k))

    (lc/blocking-subscribe chan qname cmd-message-handler)))

(defn -run [conn]
  (let  [chan  (lch/open conn)
         keys  ["telinit" "runlevel" "help" "list"]
         ex    "cmd"]

    (info (format "[MAIN] Connected. Channel id: %d" (.getChannelNumber chan)))

    (cmd-consume chan)

    (info "[MAIN] Disconnecting...")

    (rmq/close chan)))
