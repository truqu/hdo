{-# LANGUAGE DeriveFunctor         #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Network.DO.Domain.Commands where

import           Control.Comonad.Trans.Cofree
import           Control.Monad.Trans.Free
import           Data.IP
import           Network.DO.Pairing
import           Network.DO.Types
import           Prelude                      as P

data DomainCommands a = ListDomains (Result [Domain] -> a)
                      | CreateDomain DomainName IP (Result Domain -> a)
                      | DeleteDomain DomainName (Result () -> a)
                      | ListRecords DomainName (Result [DomainRecord] -> a)
                      | CreateRecord DomainName DomainRecord (Result DomainRecord -> a)
                      | DeleteRecord DomainName Id (Result () -> a)
                      deriving (Functor)

type DomainCommandsT = FreeT DomainCommands

-- smart constructors
listDomains :: DomainCommands (Result [Domain])
listDomains = ListDomains P.id

createDomain :: DomainName -> IP -> DomainCommands (Result Domain)
createDomain dname ip = CreateDomain dname ip P.id

deleteDomain :: DomainName -> DomainCommands (Result ())
deleteDomain ip = DeleteDomain ip P.id

listRecords :: DomainName -> DomainCommands (Result [DomainRecord])
listRecords n = ListRecords n P.id

createRecord :: DomainName -> DomainRecord -> DomainCommands (Result DomainRecord)
createRecord dname record = CreateRecord dname record P.id

deleteRecord :: DomainName -> Id -> DomainCommands (Result ())
deleteRecord dname rid = DeleteRecord dname rid P.id

-- dual type, for creating interpreters
data CoDomainCommands m k =
  CoDomainCommands { listDomainsH  :: (m (Result [Domain]), k)
                   , createDomainH :: DomainName -> IP -> (m (Result Domain), k)
                   , deleteDomainH :: DomainName -> (m (Result ()), k)
                   , listRecordsH  :: DomainName -> (m (Result [DomainRecord]), k)
                   , createRecordH :: DomainName -> DomainRecord -> (m (Result DomainRecord), k)
                   , deleteRecordH :: DomainName -> Id -> (m (Result ()), k)
                   } deriving Functor

-- Cofree closure of CoDomainCommands functor
type CoDomainCommandsT m = CofreeT (CoDomainCommands m)

-- pair DSL with interpreter within some monadic context
instance (Monad m) => PairingM (CoDomainCommands m) DomainCommands m where
  pairM f (CoDomainCommands ks _ _ _ _ _)    (ListDomains k)      = pairM f ks k
  pairM f (CoDomainCommands _  tgt _ _ _ _)  (CreateDomain n i k) = pairM f (tgt n i) k
  pairM f (CoDomainCommands _  _  del _ _ _) (DeleteDomain n k)   = pairM f (del n) k
  pairM f (CoDomainCommands _ _ _ ks _ _)    (ListRecords n k)    = pairM f (ks n) k
  pairM f (CoDomainCommands _  _ _ _ tgt _)  (CreateRecord n r k) = pairM f (tgt n r) k
  pairM f (CoDomainCommands _  _  _ _ _ del) (DeleteRecord n i k) = pairM f (del n i) k
