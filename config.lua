Config = {}

Config.Interact = "ox_target" -- The resource used for the target/interact system.

-- Every Entry is a locker, you can have as many lockers as you want, just copy paste the template and change the coords and job
Config.EvidenceLockers = {
  ["MRPD_Police"] = {               -- name of the locker, has to be unique, this is used for the target and the database, so choose wisely
    coords      = vector3(443.53, -974.54, 30.68),      -- coords of the locker, this is where the target will be and where you can interact with the locker
    jobs        = { "police" },   -- jobs that can access this locker min. 1 required
    withdrawRank= 2,              -- min. grade to widhdraw items from locker (grade 0 is the lowest, grade 1 is the next etc.)
    clearRank   = 3,              -- min. grade to clear locker
    deleteRank  = 4,              -- min. grade to delete locker
    stashWeight = 500000,         -- weight of the locker stash
    stashSlots  = 50,             -- slots of the locker stash  
  },

  ["Sandy_Police"] = {
    coords      = vector3(443.53, -974.54, 30.68),
    jobs        = { "ambulance" },
    withdrawRank= 2,
    clearRank   = 3,
    deleteRank  = 4,
    stashWeight = 400000,
    stashSlots  = 30,
  },

  -- Template
  ["FIB_Evidence"] = {
    coords      = vector3(250.0, -750.0, 34.0),
    jobs        = { "fib" },
    withdrawRank= 2,
    clearRank   = 3,
    deleteRank  = 4,
    stashWeight = 500000,
    stashSlots  = 40,
  }
}

